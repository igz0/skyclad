import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'package:skyclad/view/post_details.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:skyclad/providers/providers.dart';
import 'package:skyclad/view/user_profile.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  String _getPostText(Map<String, dynamic> post) {
    final record = post['record'] ?? {};
    return record?['text'] ?? '';
  }

  // 通知と投稿を取得する
  Future<Map<String, List<dynamic>>> fetchNotificationsAndPosts(
      bsky.Bluesky bluesky) async {
    final notifications = await bluesky.notifications.findNotifications();
    final List<dynamic> notificationsJson =
        notifications.toJson()['notifications'] as List<dynamic>;
    final List<String> uris = notificationsJson
        .map((notification) => notification['reasonSubject'])
        .where((uri) => uri != null)
        .cast<String>()
        .toList();

    List<dynamic> postsJson = [];

    // 25件が投稿を取得できるリミットなので25件ずつ投稿を取得する
    int batchSize = 25;
    for (int i = 0; i < uris.length; i += batchSize) {
      final batchUris = uris.sublist(i, min(i + batchSize, uris.length));
      final posts = await bluesky.feeds.findPosts(
        uris: batchUris.map((uri) => bsky.AtUri.parse(uri)).toList(),
      );
      postsJson.addAll(posts.toJson()['posts'] as List<dynamic>);
    }

    return {'notifications': notificationsJson, 'posts': postsJson};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blueskyAsyncValue = ref.watch(blueskySessionProvider);

    String getNotificationTitle(Map<String, dynamic> notification) {
      var author = notification['author'];
      String authorDisplayName = author['displayName'] ?? '';
      final localizations = AppLocalizations.of(context)!;
      final reason = notification['reason'] ?? '';

      switch (reason) {
        case 'follow':
          return localizations.followNotification(authorDisplayName);
        case 'like':
          return localizations.likeNotification(authorDisplayName);
        case 'repost':
          return localizations.repostNotification(authorDisplayName);
        case 'reply':
          return localizations.replyNotification(authorDisplayName);
        case 'mention':
          return localizations.mentionNotification(authorDisplayName);
        case 'quote':
          return localizations.quoteNotification(authorDisplayName);
        default:
          return localizations.unknownNotification;
      }
    }

    return Scaffold(
      body: blueskyAsyncValue.when(
        data: (bsky.Bluesky bluesky) {
          return FutureBuilder<Map<String, List<dynamic>>>(
            future: fetchNotificationsAndPosts(bluesky),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('エラー: ${snapshot.error}'));
              } else {
                List<dynamic> notifications = [];
                List<dynamic> posts = [];

                if (snapshot.hasData) {
                  notifications =
                      (snapshot.data!['notifications'] as List<dynamic>)
                          .map((e) => e as Map<String, dynamic>)
                          .toList();
                  posts = (snapshot.data!['posts'] as List<dynamic>)
                      .map((e) => e as Map<String, dynamic>)
                      .toList();
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notification = notifications[index];
                    var post = posts.firstWhere(
                      (post) => post['uri'] == notification['reasonSubject'],
                      orElse: () => <String, dynamic>{},
                    );

                    var author = notification['author'];
                    return Column(
                      children: [
                        ListTile(
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
                              backgroundImage: author['avatar'] != null
                                  ? NetworkImage(author['avatar'])
                                  : null,
                              radius: 24,
                              child: author['avatar'] == null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: SvgPicture.asset(
                                          'assets/default_avatar.svg',
                                          width: 48,
                                          height: 48),
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(getNotificationTitle(notification)),
                          subtitle: Text(_getPostText(post)),
                          trailing: !notification['isRead']
                              ? const Icon(Icons.fiber_manual_record,
                                  color: Colors.blue)
                              : null,
                          onTap: () {
                            // 投稿詳細画面への遷移
                            if (post.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetails(
                                    post: post,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(color: Colors.grey),
                      ],
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
