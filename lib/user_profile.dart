import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:timeago/timeago.dart' as timeago;

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ウィジェット
import 'package:skyclad/widgets/post_widget.dart';

class UserProfileScreen extends StatefulWidget {
  final String actor;

  UserProfileScreen({required this.actor});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<Map<String, dynamic>> profileData;
  late Future<List<dynamic>> postData;

  @override
  void initState() {
    super.initState();
    profileData = fetchProfileData();
    postData = fetchPostData();
  }

  Future<Map<String, dynamic>> fetchProfileData() async {
    final session = await bsky.createSession(
      identifier: dotenv.get('BLUESKY_ID'),
      password: dotenv.get('BLUESKY_PASSWORD'),
    );
    final bluesky = bsky.Bluesky.fromSession(session.data);
    final profile = await bluesky.actors.findProfile(actor: widget.actor);
    return profile.data.toJson();
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
            onPressed: () {
              // Follow/Unfollow functionality goes here
            },
            child: const Text('Follow'),
          ),
        ],
      ),
    );
  }

  Widget buildPostCard(dynamic feed) {
    final post = feed['post'];
    final author = post['author'];
    final createdAt = DateTime.parse(post['indexedAt']).toLocal();

    return Container(
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
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold),
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
          ],
        ));
  }
}