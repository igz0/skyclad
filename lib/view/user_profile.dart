import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';

// ウィジェット
import 'package:skyclad/widgets/post_widget.dart';

// 別スクリーン
import 'package:skyclad/view/post_details.dart';

class UserProfileState {
  UserProfileState({required this.profileData, required this.postData});

  final Map<String, dynamic> profileData;
  final List<dynamic> postData;
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier(this.ref)
      : super(UserProfileState(profileData: {}, postData: []));

  final StateNotifierProviderRef<UserProfileNotifier, UserProfileState> ref;

  Future<void> initUserProfile({required String actor}) async {
    final profileData = await fetchProfileData(actor: actor); // ref を引数として渡す
    final postData = await fetchPostData(actor: actor); // ref を引数として渡す
    state = UserProfileState(profileData: profileData, postData: postData);
  }

  // ユーザーのプロフィールを取得する
  Future<Map<String, dynamic>> fetchProfileData({required String actor}) async {
    final bluesky = await ref.read(blueskySessionProvider.future);
    final profile = await bluesky.actors.findProfile(actor: actor);
    return profile.data.toJson();
  }

  // ユーザーの投稿を取得する
  Future<List<dynamic>> fetchPostData({required String actor}) async {
    final bluesky = await ref.read(blueskySessionProvider.future);
    final feeds = await bluesky.feeds.findFeed(actor: actor);
    return feeds.data.toJson()['feed'];
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>(
        (ref) => UserProfileNotifier(ref));

class UserProfileScreen extends ConsumerWidget {
  final String actor;

  const UserProfileScreen({Key? key, required this.actor}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UserProfileNotifierを初期化します。
    ref.read(userProfileProvider.notifier).initUserProfile(actor: actor);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('User Profile'),
        backgroundColor: Colors.blue[600],
      ),
      body: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final state = ref.watch(userProfileProvider);

          if (state.profileData.isNotEmpty && state.postData.isNotEmpty) {
            return ListView(
              children: [
                buildProfileHeader(context, ref, state.profileData),
                ...state.postData
                    .map((post) => buildPostCard(context, post))
                    .toList(),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  // ユーザーをフォローする
  Future<void> followUser(
      BuildContext context, WidgetRef ref, String did) async {
    final bluesky = await ref.read(blueskySessionProvider.future);

    try {
      await bluesky.graphs.createFollow(did: did);

      ref.read(userProfileProvider.notifier).initUserProfile(actor: actor);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("フォローに失敗しました。時間をおいて再度やり直してください。"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// ユーザーのフォローを解除する
  Future<void> unfollowUser(
      BuildContext context, WidgetRef ref, String did) async {
    final bluesky = await ref.read(blueskySessionProvider.future);

    try {
      final profileData = ref.read(userProfileProvider).profileData;

      await bluesky.repositories.deleteRecord(
          uri: bsky.AtUri.parse(profileData['viewer']['following']));

      ref.read(userProfileProvider.notifier).initUserProfile(actor: actor);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("アンフォローに失敗しました。時間をおいて再度やり直してください。"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 投稿のプロフィールを表示するウィジェットを作成する
  Widget buildProfileHeader(
      BuildContext context, WidgetRef ref, Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(profile['avatar'] ?? ''),
                radius: 30,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile['displayName'],
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('@${profile['handle']}'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(profile['description'] ?? ''),
          if (profile['viewer']['followedBy'] != null)
            const Chip(
              label: Text('Follows you'),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Followers: ${profile['followersCount']}'),
              const SizedBox(width: 16),
              Text('Following: ${profile['followsCount']}'),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (profile['viewer']['following'] != null) {
                unfollowUser(context, ref, profile['did']);
              } else {
                followUser(context, ref, profile['did']);
              }
            },
            child: profile['viewer']['following'] != null
                ? const Text('Unfollow')
                : const Text('Follow'),
          ),
        ],
      ),
    );
  }

  // 投稿のカードを表示するウィジェットを作成する
  Widget buildPostCard(BuildContext context, dynamic feed) {
    final post = feed['post'];
    final author = post['author'];
    final createdAt = DateTime.parse(post['indexedAt']).toLocal();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetails(post: post),
          ),
        );
      },
      child: Column(
        children: [
          const Divider(height: 0),
          const SizedBox(height: 10.0),
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
                    backgroundImage: NetworkImage(author['avatar'] ?? ''),
                    radius: 24,
                  )),
              const SizedBox(width: 8.0),
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              author['displayName'] ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.0, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '@${author['handle']}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white38),
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
                      _buildRepliedBy(feed),
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }

  // 必要に応じて、_buildRepostedByと_buildRepliedByメソッドも追加します。
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
}
