import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:skyclad/providers/providers.dart';
import 'package:skyclad/view/user_profile.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  // 通知を取得する
  Future<List<dynamic>> fetchNotifications(bsky.Bluesky bluesky) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final blueskyAsyncValue = ref.watch(blueskySessionProvider);

    return Scaffold(
      body: blueskyAsyncValue.when(
        data: (bsky.Bluesky bluesky) {
          return FutureBuilder<List<dynamic>>(
            future: fetchNotifications(bluesky),
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
                      leading: GestureDetector(
                        onTap: () {
                          // ユーザー詳細画面への遷移
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
                          backgroundImage: NetworkImage(author['avatar'] ?? ''),
                        ),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
      ),
    );
  }
}
