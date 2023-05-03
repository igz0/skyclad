import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 別スクリーン
import 'package:skyclad/post_details.dart';
import 'package:skyclad/notifications.dart';
import 'package:skyclad/user_profile.dart';

// ウィジェット
import 'package:skyclad/widgets/post_widget.dart';

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
    String _appBarTitle = _appBarTitles[currentIndex];

    // ユーザープロフィール画面の場合はAppBarを非表示にする
    bool _showAppBar = currentIndex != 3; // 追加

    return MaterialApp(
      title: 'Skyclad',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: _showAppBar // 追加
            ? AppBar(
                centerTitle: true,
                title: Text(_appBarTitle),
                backgroundColor: Colors.blue[600],
              )
            : null,
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
                                  PostWidget(post: post),
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
