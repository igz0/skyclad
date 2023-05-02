import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bluesky/bluesky.dart' as bsky;

class NotificationScreen extends StatefulWidget {
  NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);

    final feeds = await bluesky.notifications.findNotifications();

    setState(() {
      notifications = feeds.toJson()['notifications'];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
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
            ),
    );
  }

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
}
