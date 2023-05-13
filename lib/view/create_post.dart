import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky_text/bluesky_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
        title: Text(widget.replyJson == null
            ? AppLocalizations.of(context)!.post
            : AppLocalizations.of(context)!.reply),
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: postController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.whatsUp,
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
                  child: Text(AppLocalizations.of(context)!.cancel),
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
                  child: Text(AppLocalizations.of(context)!.post),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 投稿を行う
  Future<void> _createPost(
      WidgetRef ref, String text, Map<String, dynamic>? replyJson) async {
    final bluesky = await ref.watch(blueskySessionProvider.future);
    final blueskyText = BlueskyText(text);

    // ファセットの作成を行う
    // 参考: https://pub.dev/documentation/bluesky_text/latest/#123-with-blueskyhttpspubdevpackagesbluesky-package
    final facets = await blueskyText.entities.toFacets();

    // リプライ先の情報を取得する
    final uri = replyJson?['uri'];
    final cid = replyJson?['cid'];

    if (uri == null) {
      // リプライ先がない場合は通常の投稿を行う
      await bluesky.feeds.createPost(
        text: blueskyText.value,
        facets: facets.map((e) => bsky.Facet.fromJson(e)).toList(),
      );
      return;
    }
    final strongRef = bsky.StrongRef(cid: cid, uri: bsky.AtUri.parse(uri));

    bsky.ReplyRef replyRef = bsky.ReplyRef(parent: strongRef, root: strongRef);

    await bluesky.feeds.createPost(
        text: blueskyText.value,
        reply: replyRef,
        facets: facets.map((e) => bsky.Facet.fromJson(e)).toList());
  }
}
