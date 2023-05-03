import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ウィジェット
import 'package:skyclad/widgets/post_widget.dart';

// 別スクリーン
import 'package:skyclad/post_details.dart';

class UserProfileScreen extends StatefulWidget {
  final String actor;

  UserProfileScreen({required this.actor});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<Map<String, dynamic>> profileData;
  late Future<List<dynamic>> postData;
  Map<String, dynamic> _profileData = {}; // 追加

  @override
  void initState() {
    super.initState();
    profileData = fetchProfileData();
    postData = fetchPostData();
  }

  Future<void> followUser(String did) async {
    try {
      final session = await bsky.createSession(
        identifier: dotenv.get('BLUESKY_ID'),
        password: dotenv.get('BLUESKY_PASSWORD'),
      );
      final bluesky = bsky.Bluesky.fromSession(session.data);
      final followResult = await bluesky.graphs.createFollow(did: did); // 追加

      // Update the _profileData to reflect the follow status
      setState(() {
        _profileData['viewer']['following'] =
            followResult.data.toJson()['uri']; // 変更
      });
    } catch (e) {
      print("Error following user: $e");
    }
  }

  Future<void> unfollowUser(String did) async {
    try {
      final session = await bsky.createSession(
        identifier: dotenv.get('BLUESKY_ID'),
        password: dotenv.get('BLUESKY_PASSWORD'),
      );
      final bluesky = bsky.Bluesky.fromSession(session.data);

      await bluesky.repositories.deleteRecord(
          uri: bsky.AtUri.parse(_profileData['viewer']['following']));

      // Update the profileData to reflect the unfollow status
      setState(() {
        _profileData['viewer']['following'] = null;
      });
    } catch (e) {
      print("Error unfollowing user: $e");
    }
  }

  Future<Map<String, dynamic>> fetchProfileData() async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);
    final profile = await bluesky.actors.findProfile(actor: widget.actor);
    _profileData = profile.data.toJson(); // 追加
    return _profileData;
  }

  Future<List<dynamic>> fetchPostData() async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);
    final feeds = await bluesky.feeds.findFeed(actor: widget.actor);
    return feeds.data.toJson()['feed'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('User Profile'),
        backgroundColor: Colors.blue[600],
      ),
      body: FutureBuilder(
        future: Future.wait([profileData, postData]),
        builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            Map<String, dynamic> profile = snapshot.data![0];
            List<dynamic> posts = snapshot.data![1];

            return ListView(
              children: [
                buildProfileHeader(profile),
                ...posts.map((post) => buildPostCard(post)).toList(),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget buildProfileHeader(Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(profile['avatar']),
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
                unfollowUser(profile['did']);
              } else {
                followUser(profile['did']);
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

  Widget buildPostCard(dynamic feed) {
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
                      PostWidget(post: post), // これを使用します。
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }
}
