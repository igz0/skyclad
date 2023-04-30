import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class PostDetails extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetails({required this.post, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final author = post['author'];
    final createdAt = DateTime.parse(post['indexedAt']).toLocal();

    DateFormat format = DateFormat('yyyy/MM/dd HH:mm');
    String dateStr = format.format(createdAt);

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(post['author']['avatar']),
                  radius: 20,
                ),
                const SizedBox(width: 10.0),
                Flexible(
                  child: Text(
                    author['displayName'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.0),
                  ),
                ),
                Flexible(
                  child: Text(
                    '@${author['handle']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Text(
              post['record']['text'],
              style: const TextStyle(fontSize: 15.0),
            ),
            const SizedBox(height: 15.0),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 12.0, color: Colors.white38),
            ),
            const SizedBox(height: 10.0),
            const Divider(height: 1, thickness: 1, color: Colors.white12),
            const SizedBox(height: 10.0),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Column(children: [
                Text(post['repostCount'].toString()),
                const Text('リポスト')
              ]),
              Column(children: [
                Text(post['likeCount'].toString()),
                const Text('いいね')
              ]),
            ]),
            const SizedBox(height: 10.0),
            const Divider(height: 1, thickness: 1, color: Colors.white12),
          ],
        ),
      ),
    );
  }
}
