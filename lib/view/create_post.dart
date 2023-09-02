import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky_text/bluesky_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skyclad/providers/providers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? replyJson;

  const CreatePostScreen({Key? key, this.replyJson}) : super(key: key);

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController postController = TextEditingController();
  List<File> imageFiles = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.replyJson == null
            ? AppLocalizations.of(context)!.post
            : AppLocalizations.of(context)!.reply),
        backgroundColor: Colors.blue[600],
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () async {
              if (postController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _createPost(
                    ref, postController.text.trim(), widget.replyJson);
                postController.clear();
                imageFiles.clear();
              }
            },
          ),
        ],
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
            Container(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: imageFiles.length < 4
                    ? () async {
                        final pickedFile = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (pickedFile != null) {
                          setState(() {
                            imageFiles.add(File(pickedFile.path));
                          });
                        }
                      }
                    : null,
                child: const Icon(Icons.add_photo_alternate),
              ),
            ),
            // 選択した画像をサムネイルとして表示する
            Container(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 8.0, // 列間
                  runSpacing: 4.0, // 行間
                  children: imageFiles.asMap().entries.map((entry) {
                    int index = entry.key;
                    File file = entry.value;
                    return Stack(
                      children: <Widget>[
                        Image.file(
                          file,
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                imageFiles.removeAt(index);
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost(
      WidgetRef ref, String text, Map<String, dynamic>? replyJson) async {
    final bluesky = await ref.watch(blueskySessionProvider.future);
    final blueskyText = BlueskyText(text);

    // テキストを解析して、ファセットを取得する
    final facets = await blueskyText.entities.toFacets();

    // リプライ先の情報を取得する
    final uri = replyJson?['uri'];
    final cid = replyJson?['cid'];

    // 画像をアップロードする
    List<bsky.Image> images = [];
    for (var imageFile in imageFiles) {
      final uploaded = await bluesky.repositories.uploadBlob(
        imageFile.readAsBytesSync(),
      );

      images.add(
        bsky.Image(
          alt: "",
          image: uploaded.data.blob,
        ),
      );
    }

    // 画像がある場合は画像を添付する
    bsky.Embed? embed = images.isNotEmpty
        ? bsky.Embed.images(
            data: bsky.EmbedImages(
              images: images,
            ),
          )
        : null;

    // リプライ先がない場合は通常の投稿を行う
    if (uri == null) {
      await bluesky.feeds.createPost(
        text: blueskyText.value,
        facets: facets.map((e) => bsky.Facet.fromJson(e)).toList(),
        embed: embed,
      );
      return;
    }

    final strongRef = bsky.StrongRef(cid: cid, uri: bsky.AtUri.parse(uri));
    bsky.ReplyRef replyRef = bsky.ReplyRef(parent: strongRef, root: strongRef);

    await bluesky.feeds.createPost(
      text: blueskyText.value,
      reply: replyRef,
      facets: facets.map(bsky.Facet.fromJson).toList(),
      embed: embed,
    );
  }
}
