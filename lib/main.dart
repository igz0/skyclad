import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 別スクリーン
import 'package:skyclad/post_details.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  timeago.setLocaleMessages("ja", timeago.JaMessages());
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  final GlobalKey<BlueskyTimelineState> blueskyTimelineKey =
      GlobalKey<BlueskyTimelineState>();

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skyclad',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Timeline'),
          backgroundColor: Colors.blue[600],
        ),
        body: BlueskyTimeline(timelineKey: blueskyTimelineKey),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showCreatePostDialog(context);
          },
          backgroundColor: Colors.blue[600],
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: '検索',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: '通知',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'プロフィール',
            ),
          ],
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white38,
          showUnselectedLabels: true,
        ),
      ),
    );
  }

  // 新しい投稿作成ダイアログを表示
  Future<void> _showCreatePostDialog(BuildContext context) async {
    TextEditingController postController = TextEditingController();
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新しい投稿を作成'),
          content: TextField(
            controller: postController,
            decoration: const InputDecoration(
              hintText: '投稿内容を入力してください',
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                if (postController.text.trim().isNotEmpty) {
                  Navigator.pop(context);

                  await _createPost(postController.text.trim());
                  postController.clear();

                  // Call the callback
                  blueskyTimelineKey.currentState!._refreshTimeline();
                }
              },
              child: const Text('投稿'),
            ),
          ],
        );
      },
    );
  }

  // 投稿を作成する
  Future<void> _createPost(String text) async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);
    await bluesky.feeds.createPost(
      text: text,
    );
  }
}

@immutable
class BlueskyTimeline extends StatefulWidget {
  final GlobalKey<BlueskyTimelineState> timelineKey;

  const BlueskyTimeline({required this.timelineKey, Key? key})
      : super(key: key);

  @override
  BlueskyTimelineState createState() => BlueskyTimelineState();
}

class BlueskyTimelineState extends State<BlueskyTimeline> {
  List<dynamic> _timelineData = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  // 初期化処理
  @override
  void initState() {
    super.initState();
    _fetchTimeline();
  }

  // タイムラインを取得する
  Future<void> _fetchTimeline() async {
    final data = await _fetchTimelineData();
    setState(() {
      _timelineData = data;
      _isLoading = false;
    });
  }

  // タイムラインを更新する
  Future<void> _refreshTimeline() async {
    setState(() {
      _isRefreshing = true;
    });
    final data = await _fetchTimelineData();
    setState(() {
      _timelineData = data;
      _isRefreshing = false;
    });
  }

  Future<List<dynamic>> _fetchTimelineData() async {
    // 既存の_fetchTimelineメソッドの内容をここに移動
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);
    final feeds = await bluesky.feeds.findTimeline(limit: 100);

    // タイムラインのJSONを取得する
    final jsonFeeds = feeds.data.toJson()['feed'];

    return jsonFeeds;
  }

  Widget _buildPostContent(Map<String, dynamic> post) {
    List<Widget> contentWidgets = [];

    // 投稿文を追加する
    contentWidgets.add(
      Text(
        post['record']['text'],
        style: const TextStyle(fontSize: 15.0),
      ),
    );

    // 投稿に画像が含まれていたら追加する
    if (post['embed'] != null &&
        post['embed']['\$type'] == 'app.bsky.embed.images#view') {
      contentWidgets.add(const SizedBox(height: 10.0));

      // 画像ウィジェットを作成する
      List<Widget> imageWidgets = post['embed']['images'].map<Widget>((image) {
        return GestureDetector(
          onTap: () => _showImageDialog(context, image['fullsize']),
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                image['thumb'],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }).toList();

      // 画像ウィジェットに水平スクロールを追加する
      contentWidgets.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: imageWidgets,
          ),
        ),
      );

      // 引用投稿が含まれていたら追加する
      contentWidgets.add(_buildQuotedPost(post));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  Widget _buildRepostedBy(Map<String, dynamic> feed) {
    if (feed['reason'] != null &&
        feed['reason']['\$type'] == 'app.bsky.feed.defs#reasonRepost') {
      final repostedBy = feed['reason']['by'];
      return Column(children: [
        Text(
          'Reposted by @${repostedBy['displayName']}',
          style: const TextStyle(color: Colors.white38, fontSize: 12.0),
        ),
        const SizedBox(height: 8.0),
      ]);
    }
    return const SizedBox.shrink();
  }
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildQuotedPost(Map<String, dynamic> post) {
    if (post['embed'] != null &&
        post['embed']['\$type'] == 'app.bsky.embed.record#view') {
      final quotedPost = post['embed']['record'];
      final quotedAuthor = quotedPost['author'];
      final createdAt = DateTime.parse(quotedPost['indexedAt']).toLocal();

      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white38),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8.0),
        margin: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    quotedAuthor['displayName'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.0, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    '@${quotedAuthor['handle']}',
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12.0),
                  ),
                ),
                Text(
                  timeago.format(createdAt, locale: "ja"),
                  style: const TextStyle(fontSize: 12.0),
                  overflow: TextOverflow.clip,
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Text(
              quotedPost['record']['text'],
              style: const TextStyle(fontSize: 14.0),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

// 画像をダイアログで表示する
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          insetPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              Center(
                // 画像を縦方向にスワイプして閉じるようにする
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.vertical,
                  onDismissed: (direction) {
                    Navigator.pop(context);
                  },
                  child: Image.network(
                    imageUrl,
                    width: screenWidth,
                    height: screenHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // タイムラインを表示する
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (!_isRefreshing) {
          await _refreshTimeline();
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _timelineData.length,
        itemBuilder: (context, index) {
          final feed = _timelineData[index];
          final post = feed['post'];
          final author = post['author'];
          final createdAt = DateTime.parse(post['indexedAt']).toLocal();

          return Column(children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetails(post: post),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // ここを追加
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(author['avatar'] ?? ''),
                      radius: 24,
                    ),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRepostedBy(feed),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    author['displayName'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '@${author['handle']}',
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(color: Colors.white38),
                                  ),
                                ),
                                Text(
                                  timeago.format(createdAt, locale: "ja"),
                                  style: const TextStyle(fontSize: 12.0),
                                  overflow: TextOverflow.clip,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10.0),
                            _buildPostContent(post),
                          ]),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.white12)
          ]);
        },
      ),
    );
  }
}
