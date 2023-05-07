import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';
import 'package:skyclad/view/user_profile.dart';

class RepostedByScreen extends ConsumerWidget {
  final String uri;

  RepostedByScreen({required this.uri});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('リポストしたユーザー'),
        backgroundColor: Colors.blue[600],
      ),
      body: FutureBuilder(
        future: _fetchRepostedByUsers(ref, uri),
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final user = snapshot.data![index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user['avatar'] ?? ''),
                    ),
                    title: Text(user['displayName'] ?? ''),
                    subtitle: Text('@${user['handle']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            actor: user['handle'],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            } else {
              return const Center(child: Text('リポストしたユーザーがいません'));
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<List> _fetchRepostedByUsers(WidgetRef ref, String uri) async {
    final bluesky = await ref.read(blueskySessionProvider.future);
    final repostedBy =
        await bluesky.feeds.findRepostedBy(uri: bsky.AtUri.parse(uri));

    final repostedByJson = repostedBy.data.toJson();
    return repostedByJson['repostedBy'];
  }
}
