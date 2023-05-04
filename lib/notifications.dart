import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bluesky/bluesky.dart' as bsky;

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  // 通知を取得する
  Future<List<dynamic>> fetchNotifications() async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);

    final feeds = await bluesky.notifications.findNotifications();

    return feeds.toJson()['notifications'];
  }

  // 通知の種類に応じて通知の内容を返す
  String _getNotificationText(Map<String, dynamic> notification) {
    switch (notification['reason']) {
      case 'follow':
        return 'フォローされました。';
      case 'like':
        return 'いいね！されました。';
      case 'repost':
        return 'リポストされました。';
      default:
        return '不明な通知です。';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: fetchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          } else {
            List<dynamic> notifications = snapshot.data!;
            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                var notification = notifications[index];
                var author = notification['author'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(author['avatar'] ?? ''),
                  ),
                  title: Text(author['displayName'] ?? ''),
                  subtitle: Text(_getNotificationText(notification)),
                  trailing: !notification['isRead']
                      ? const Icon(Icons.fiber_manual_record,
                          color: Colors.blue)
                      : null,
                );
              },
            );
          }
        },
      ),
    );
  }
}
