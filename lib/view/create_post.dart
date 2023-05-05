// create_post_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';

class CreatePostScreen extends ConsumerWidget {
  final TextEditingController postController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新しい投稿を作成'),
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

                      await _createPost(ref, postController.text.trim());
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

  Future<void> _createPost(WidgetRef ref, String text) async {
    final bluesky = await ref.watch(blueskySessionProvider.future);
    await bluesky.feeds.createPost(
      text: text,
    );
  }
}
