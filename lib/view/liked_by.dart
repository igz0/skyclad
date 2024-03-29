import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';
import 'package:skyclad/view/user_profile.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LikedByScreen extends ConsumerWidget {
  final String uri;

  const LikedByScreen({Key? key, required this.uri}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(AppLocalizations.of(context)!.likedUser),
        backgroundColor: Colors.blue[600],
      ),
      body: FutureBuilder(
        future: _fetchLikedByUsers(ref, uri),
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final user = snapshot.data![index]['actor'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatar'] != null
                          ? NetworkImage(user['avatar'])
                          : null,
                      radius: 24,
                      child: user['avatar'] == null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: SvgPicture.asset(
                                  'assets/default_avatar.svg',
                                  width: 48,
                                  height: 48),
                            )
                          : null,
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
              return Center(
                  child: Text(AppLocalizations.of(context)!.noUsersLiked));
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<List> _fetchLikedByUsers(WidgetRef ref, String uri) async {
    final bluesky = await ref.read(blueskySessionProvider.future);
    final likedBy =
        await bluesky.feeds.findLikes(uri: bsky.AtUri.parse(uri), limit: 100);

    final likedByJson = likedBy.data.toJson();
    return likedByJson['likes'];
  }
}
