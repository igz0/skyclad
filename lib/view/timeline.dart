import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyclad/model/current_index.dart';
import 'package:skyclad/providers/providers.dart';

// 別スクリーン
import 'package:skyclad/view/notifications.dart';
import 'package:skyclad/view/user_profile.dart';
import 'package:skyclad/view/login.dart';
import 'package:skyclad/view/post_details.dart';

// ウィジェット
import 'package:skyclad/widgets/post_widget.dart';

// ウィジェット
class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<BlueskyTimelineState> blueskyTimelineKey =
      GlobalKey<BlueskyTimelineState>();

  @override
  Widget build(BuildContext context) {
    int currentIndex = ref.watch(currentIndexProvider);
    return MaterialApp(
      title: 'Skyclad',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: _buildAppBar(currentIndex),
        body: _buildBody(currentIndex),
        floatingActionButton: _buildFloatingActionButton(context),
        bottomNavigationBar: _buildBottomNavigationBar(currentIndex),
        drawer: _buildDrawer(context),
        drawerEdgeDragWidth: 0, // ドロワーを開くジェスチャーを無効化
      ),
    );
  }

  // AppBarを生成する関数
  AppBar? _buildAppBar(int currentIndex) {
    if (currentIndex == 2) return null;
    return AppBar(
      centerTitle: true,
      title: Text([
        'ホーム',
        '通知',
        'プロフィール',
      ][currentIndex]),
      backgroundColor: Colors.blue[600],
    );
  }

  // タイムラインのコンテンツを生成する関数
  Widget _buildBody(int currentIndex) {
    return FutureBuilder<String>(
      future: ref.read(sharedPreferencesRepositoryProvider).getId(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // データがまだ来ていないときはローディングインジケータを表示
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}'); // エラーが発生した場合はエラーメッセージを表示
        } else {
          // データがロードされたらそれを使用してUIを構築
          final id = snapshot.data;
          return [
            BlueskyTimeline(
              timelineKey: blueskyTimelineKey,
            ),
            const Placeholder(),
            const NotificationScreen(),
            UserProfileScreen(actor: id ?? ''),
          ][currentIndex];
        }
      },
    );
  }

  // BottomNavigationBarを生成する関数
  BottomNavigationBar _buildBottomNavigationBar(int currentIndex) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'ホーム',
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
        ref.read(currentIndexProvider.notifier).updateIndex(index);
      },
    );
  }

  // Drawerを生成する関数
  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.lightBlue),
            child: Text('Skyclad', style: TextStyle(fontSize: 24)),
          ),
          ListTile(
            title: const Text('ログアウト'),
            onTap: () async {
              // ログアウト処理
              final sharedPreferences = await SharedPreferences.getInstance();
              sharedPreferences.remove('id');
              sharedPreferences.remove('password'); // ログイン画面に遷移

              // ignore: use_build_context_synchronously
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // FloatingActionButtonを生成する関数
  FloatingActionButton _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        _showCreatePostDialog(context);
      },
      backgroundColor: Colors.blue[600],
      child: const Icon(Icons.edit, color: Colors.white),
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
                  // blueskyTimelineKey.currentState!._refreshTimeline();
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
    final bluesky = await ref.read(blueskySessionProvider.future);
    await bluesky.feeds.createPost(
      text: text,
    );
  }
}

@immutable
class BlueskyTimeline extends ConsumerStatefulWidget {
  final GlobalKey<BlueskyTimelineState> timelineKey;

  const BlueskyTimeline({required this.timelineKey, Key? key})
      : super(key: key);

  @override
  BlueskyTimelineState createState() => BlueskyTimelineState();
}

class BlueskyTimelineState extends ConsumerState<BlueskyTimeline> {
  List<dynamic> _timelineData = [];
  String _cursor = "";
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String? _nextCursor;
  final bool _hasMoreData = true;

  // 初期化処理
  @override
  void initState() {
    super.initState();
    _fetchTimeline();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PrimaryScrollController.of(context).addListener(_scrollListener);
  }

  void _scrollListener() {
    ScrollController controller = PrimaryScrollController.of(context);

    if (controller.position.pixels == controller.position.maxScrollExtent) {
      _loadMoreTimelineData();
    }
  }

  @override
  void deactivate() {
    super.deactivate();
    PrimaryScrollController.of(context).removeListener(_scrollListener);
  }

  // タイムラインを取得する
  Future<void> _fetchTimeline() async {
    final data = await _fetchTimelineData();

    if (!mounted) {
      return;
    }
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
    final bluesky = await ref.read(blueskySessionProvider.future);
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
