import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? replyJson;

  CreatePostScreen({Key? key, this.replyJson}) : super(key: key);

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController postController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('新しい投稿を作成'),
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: postController,
              decoration: const InputDecoration(
                hintText: '投稿内容を入力してください',
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (postController.text.trim().isNotEmpty) {
                      Navigator.pop(context);

                      await _createPost(
                          ref, postController.text.trim(), widget.replyJson);
                      postController.clear();
                    }
                  },
                  child: const Text('投稿'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // リプライを作成する
  Future<void> _createPost(
      WidgetRef ref, String text, Map<String, dynamic>? replyJson) async {
    final bluesky = await ref.watch(blueskySessionProvider.future);

    // 返信先の情報を取得する
    final uri = replyJson?['uri'];
    final cid = replyJson?['cid'];

    if (uri == null) {
      // リプライ先がない場合は通常の投稿を行う
      await bluesky.feeds.createPost(
        text: text,
      );
      return;
    }
    final strongRef = bsky.StrongRef(cid: cid, uri: bsky.AtUri.parse(uri));

    bsky.ReplyRef replyRef = bsky.ReplyRef(parent: strongRef, root: strongRef);

    await bluesky.feeds.createPost(text: text, reply: replyRef);
  }
}
