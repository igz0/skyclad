import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  Widget buildPostCard(dynamic post) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['post']['record']['text'],
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Replies: ${post['post']['replyCount']}'),
                Text('Reposts: ${post['post']['repostCount']}'),
                Text('Likes: ${post['post']['likeCount']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
