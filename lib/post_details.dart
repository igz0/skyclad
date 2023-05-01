import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PostDetails extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetails({required this.post, Key? key}) : super(key: key);

  @override
  _PostDetailsState createState() => _PostDetailsState();
}

class _PostDetailsState extends State<PostDetails> {
  Map<String, dynamic> _post;

  _PostDetailsState() : _post = {};

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  Widget build(BuildContext context) {
    final author = _post['author'];
    final createdAt = DateTime.parse(_post['indexedAt']).toLocal();

    DateFormat format = DateFormat('yyyy/MM/dd HH:mm');
    String dateStr = format.format(createdAt);

    bool isLiked = _post['viewer']['like'] != null;
    bool isReposted = _post['viewer']['repost'] != null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(author['displayName'] ?? ''),
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage:
                      NetworkImage(_post['author']['avatar'] ?? ''),
                  radius: 20,
                ),
                const SizedBox(width: 10.0),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    author['displayName'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.0),
                  ),
                  Text(
                    '@${author['handle']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 10.0),
            Text(
              _post['record']['text'],
              style: const TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 15.0),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 14.0, color: Colors.white38),
            ),
            const SizedBox(height: 10.0),
            const Divider(height: 1, thickness: 1, color: Colors.white12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Column(children: [
                IconButton(
                  icon: const Icon(Icons.reply),
                  onPressed: () {
                    // TODO: 返信処理
                  },
                ),
              ]),
              Column(children: [
                IconButton(
                  icon: isReposted
                      ? const Icon(Icons.cached)
                      : const Icon(Icons.cached_outlined),
                  color: isReposted ? Colors.green : null,
                  onPressed: () async {
                    final session = await bsky.createSession(
                      identifier: dotenv.get('BLUESKY_ID'),
                      password: dotenv.get('BLUESKY_PASSWORD'),
                    );
                    final bluesky = bsky.Bluesky.fromSession(session.data);

                    if (isReposted) {
                      // リポストを取り消し
                      await bluesky.repositories.deleteRecord(
                        uri: _post['viewer']['repost']['uri'],
                      );
                    } else {
                      // リポスト処理
                      final repostedRecord = await bluesky.feeds.createRepost(
                        cid: _post['cid'],
                        uri: bsky.AtUri.parse(_post['uri']),
                      );
                      _post['viewer']
                          ['repost'] = {'uri': repostedRecord.data.uri};
                    }
                    setState(() {
                      if (isReposted) {
                        _post['viewer']['repost'] = null;
                        _post['repostCount'] -= 1;
                      } else {
                        _post['repostCount'] += 1;
                      }
                    });
                  },
                ),
              ]),
              Column(children: [
                IconButton(
                  icon: isLiked
                      ? const Icon(Icons.favorite)
                      : const Icon(Icons.favorite_border),
                  color: isLiked ? Colors.red : null,
                  onPressed: () async {
                    final session = await bsky.createSession(
                      identifier: dotenv.get('BLUESKY_ID'),
                      password: dotenv.get('BLUESKY_PASSWORD'),
                    );
                    final bluesky = bsky.Bluesky.fromSession(session.data);

                    if (isLiked) {
                      // いいねを取り消し
                      await bluesky.repositories.deleteRecord(
                        uri: _post['viewer']['like']['uri'],
                      );
                    } else {
                      // いいね処理
                      final likedRecord = await bluesky.feeds.createLike(
                        cid: _post['cid'],
                        uri: bsky.AtUri.parse(_post['uri']),
                      );
                      _post['viewer']['like'] = {'uri': likedRecord.data.uri};
                    }
                    setState(() {
                      if (isLiked) {
                        _post['viewer']['like'] = null;
                        _post['likeCount'] -= 1;
                      } else {
                        _post['likeCount'] += 1;
                      }
                    });
                  },
                ),
              ]),
            ]),
            const Divider(height: 1, thickness: 1, color: Colors.white12),
            const SizedBox(height: 10.0),
            Row(
              children: [
                const SizedBox(width: 10.0),
                Row(
                  children: [
                    Text(
                      '${_post['repostCount'].toString()} リポスト',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 10.0),
                    Text('${_post['likeCount'].toString()} いいね',
                        style: const TextStyle(fontSize: 16)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 10.0),
            const Divider(height: 1, thickness: 1, color: Colors.white12),
          ],
        ),
      ),
    );
  }
}
