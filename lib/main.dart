import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:linkify/linkify.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:card_swiper/card_swiper.dart';

// 別スクリーン
import 'package:skyclad/post_details.dart';
import 'package:skyclad/notifications.dart';
import 'package:skyclad/user_profile.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  timeago.setLocaleMessages("ja", timeago.JaMessages());
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final GlobalKey<BlueskyTimelineState> blueskyTimelineKey =
      GlobalKey<BlueskyTimelineState>();
  int currentIndex = 0;
  late List<Widget> _pages;

  final List<String> _appBarTitles = ['Timeline', '検索', '通知', 'プロフィール'];

  @override
  void initState() {
    super.initState();
    _pages = [
      BlueskyTimeline(timelineKey: blueskyTimelineKey),
      const Placeholder(),
      NotificationScreen(),
      UserProfileScreen(actor: dotenv.get('BLUESKY_ID')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skyclad',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(_appBarTitles[currentIndex]),
          backgroundColor: Colors.blue[600],
        ),
        body: _pages[currentIndex],
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
          currentIndex: currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white38,
          showUnselectedLabels: true,
          onTap: (int index) {
            setState(() {
              currentIndex = index;
            });
          },
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

                  // コールバックを呼び出してタイムラインを更新
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
  String _cursor = "";
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String? _nextCursor;
  final bool _hasMoreData = true; // この行を追加
  final ScrollController _scrollController = ScrollController();

  // 初期化処理
  @override
  void initState() {
    super.initState();
    _fetchTimeline();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // タイムラインを取得する
  Future<void> _fetchTimeline() async {
    final data = await _fetchTimelineData();
    setState(() {
      _timelineData = data['feed'];
      _nextCursor = data['cursor'];
      _isLoading = false;
    });
  }

  // タイムラインを更新する
  Future<void> _refreshTimeline() async {
    final data = await _fetchTimelineData();
    setState(() {
      _timelineData = data['feed'];
      _cursor = data['cursor'];
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreTimelineData();
    }
  }

  // タイムラインデータを追加で取得する
  Future<void> _loadMoreTimelineData() async {
    if (!_isFetchingMore && _hasMoreData) {
      setState(() {
        _isFetchingMore = true;
      });

      final moreData = await _fetchTimelineData(cursor: _nextCursor);

      setState(() {
        _timelineData.addAll(moreData['feed']);
        _nextCursor = moreData['cursor'];
        _isFetchingMore = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchTimelineData({String? cursor}) async {
    // 既存の_fetchTimelineメソッドの内容をここに移動
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);

    final feeds = await bluesky.feeds.findTimeline(limit: 100, cursor: cursor);

    // タイムラインのJSONを取得する
    final jsonFeeds = feeds.data.toJson()['feed'];

    // カーソルを更新
    _cursor = feeds.data.toJson()['cursor'];

    // タイムラインのフィードとカーソルを返す
    return {'feed': jsonFeeds, 'cursor': _cursor};
  }

  // 投稿のウィジェットを作成する
  Widget _buildPostContent(Map<String, dynamic> post) {
    List<Widget> contentWidgets = [];

    // 投稿文を追加する
    final elements = linkify(post['record']['text'],
        options: const LinkifyOptions(humanize: false));
    final List<InlineSpan> spans = [];

    // 投稿文の要素をウィジェットに変換する
    for (final element in elements) {
      if (element is TextElement) {
        spans.add(TextSpan(text: element.text));
      } else if (element is UrlElement) {
        spans.add(TextSpan(
          text: element.text,
          style: const TextStyle(color: Colors.blue),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final messenger = ScaffoldMessenger.of(context);
              if (await canLaunchUrl(Uri.parse(element.url))) {
                await launchUrl(Uri.parse(element.url),
                    mode: LaunchMode.externalApplication);
              } else {
                messenger.showSnackBar(
                  const SnackBar(content: Text("リンクを開けませんでした。")),
                );
              }
            },
        ));
      }
    }

    // 投稿文をウィジェットに追加する
    contentWidgets.add(
      RichText(
        text: TextSpan(
          children: spans,
          style: const TextStyle(fontSize: 15.0, color: Colors.white),
        ),
      ),
    );

    // 投稿に画像が含まれていたら追加する
    if (post['embed'] != null &&
        post['embed']['\$type'] == 'app.bsky.embed.images#view') {
      contentWidgets.add(const SizedBox(height: 10.0));

      // 画像ウィジェットを作成する
      List<String> imageUrls = post['embed']['images']
          .map<String>((dynamic image) => image['fullsize'] as String)
          .toList();

      // タップで画像ダイアログを表示する
      contentWidgets.add(
        GestureDetector(
          onTap: () => _showImageDialog(context, imageUrls),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: post['embed']['images']
                  .map<Widget>((image) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            image['thumb'],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      );
    }

    // 引用投稿が含まれていたら追加する
    contentWidgets.add(_buildQuotedPost(post));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  // 投稿がリポストだった場合にリポストであることを表記したウィジェットを作成する
  Widget _buildRepostedBy(Map<String, dynamic> feed) {
    if (feed['reason'] != null &&
        feed['reason']['\$type'] == 'app.bsky.feed.defs#reasonRepost') {
      final repostedBy = feed['reason']['by'];
      return Column(children: [
        const SizedBox(height: 8.0),
        Text(
          'Reposted by @${repostedBy['displayName']}',
          style: const TextStyle(color: Colors.white38, fontSize: 12.0),
        ),
      ]);
    }
    return const SizedBox.shrink();
  }

  // 投稿がリプライだった場合にリプライであることを表記したウィジェットを作成する
  Widget _buildRepliedBy(Map<String, dynamic> feed) {
    if (feed['reply'] != null) {
      final repliedTo = feed['reply']['parent']['author'];
      return Column(
        children: [
          const SizedBox(height: 8.0),
          Text(
            'Reply to ${repliedTo['displayName']}',
            style: const TextStyle(color: Colors.white38, fontSize: 12.0),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // 引用投稿先のJSONを取得する
  Future<Map<String, dynamic>> _fetchQuotedPost(String uri) async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);
    final feeds = await bluesky.feeds.findPosts(uris: [bsky.AtUri.parse(uri)]);

    // 引用投稿先のJSONを取得する
    final jsonFeed = feeds.data.toJson()['posts'][0];

    return jsonFeed;
  }

  // 引用投稿のウィジェットを作成する
  Widget _buildQuotedPost(Map<String, dynamic> post) {
    if (post['embed'] != null &&
        post['embed']['\$type'] == 'app.bsky.embed.record#view') {
      final quotedPost = post['embed']['record'];
      final quotedAuthor = quotedPost['author'];
      final createdAt = DateTime.parse(quotedPost['indexedAt']).toLocal();

      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FutureBuilder(
                future: _fetchQuotedPost(quotedPost['uri']),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    return PostDetails(post: snapshot.data);
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          );
        },
        child: Container(
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
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12.0),
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
                quotedPost['value']['text'] ?? '',
                style: const TextStyle(fontSize: 14.0),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // 画像をダイアログで表示する
  void _showImageDialog(BuildContext context, List<String> imageUrls) {
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
              MediaQuery(
                data: MediaQuery.of(context),
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.vertical,
                  onDismissed: (direction) {
                    Navigator.pop(context);
                  },
                  child: SizedBox(
                    width: screenWidth,
                    height: screenHeight,
                    child: Swiper(
                      itemBuilder: (BuildContext context, int index) {
                        return Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error),
                            );
                          },
                        );
                      },
                      itemCount: imageUrls.length,
                      loop: false,
                    ),
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
      onRefresh: () => _refreshTimeline(),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _timelineData.length + 1,
        itemBuilder: (context, index) {
          // 最後の要素の場合、_hasMoreData が true ならローディングアイコンを表示、そうでなければ空のコンテナを表示
          if (index == _timelineData.length) {
            return _hasMoreData
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox.shrink();
          }

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
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                      actor: author['handle'],
                                    ),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundImage:
                                    NetworkImage(author['avatar'] ?? ''),
                                radius: 24,
                              )),
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                          style: const TextStyle(
                                              color: Colors.white38),
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
                                  _buildRepostedBy(feed),
                                  _buildRepliedBy(feed)
                                ]),
                          ),
                        ],
                      ),
                    ],
                  )),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.white12)
          ]);
        },
      ),
    );
  }
}
