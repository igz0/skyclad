import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 別スクリーン
import 'package:skyclad/notifications.dart';
import 'package:skyclad/user_profile.dart';
import 'package:skyclad/timeline.dart';

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
      const NotificationScreen(),
      UserProfileScreen(actor: dotenv.get('BLUESKY_ID')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = _appBarTitles[currentIndex];

    // ユーザープロフィール画面の場合はAppBarを非表示にする
    bool isShowAppBar = currentIndex != 3; // 追加

    return MaterialApp(
      title: 'Skyclad',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: isShowAppBar // 追加
            ? AppBar(
                centerTitle: true,
                title: Text(appBarTitle),
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
