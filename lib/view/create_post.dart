import 'dart:io';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky_text/bluesky_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skyclad/providers/providers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

class CreatePostScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? replyJson;
  final Map<String, dynamic>? quoteJson;

  const CreatePostScreen({Key? key, this.replyJson, this.quoteJson})
      : super(key: key);

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
        title: _buildAppBarTitle(context),
        backgroundColor: Colors.blue[600],
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () async {
              if (postController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _createPost(ref, postController.text.trim(),
                    widget.replyJson, widget.quoteJson);
                postController.clear();
                imageFiles.clear();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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
            // 引用ポストの内容を表示
            if (widget.quoteJson != null) ...[
              const SizedBox(height: 16.0),
              _displayQuotedPost(widget.quoteJson!),
              const SizedBox(height: 16.0),
            ],
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
        )),
      ),
    );
  }

  Text _buildAppBarTitle(BuildContext context) {
    if (widget.quoteJson != null) {
      return Text(AppLocalizations.of(context)!.quote);
    }
    return Text(widget.replyJson == null
        ? AppLocalizations.of(context)!.post
        : AppLocalizations.of(context)!.reply);
  }

  Future<void> _createPost(WidgetRef ref, String text,
      Map<String, dynamic>? replyJson, Map<String, dynamic>? quoteJson) async {
    final bluesky = await ref.watch(blueskySessionProvider.future);
    final blueskyText = BlueskyText(text);

    // テキストを解析して、ファセットを取得する
    final facets = await blueskyText.entities.toFacets();

    // リプライ先の情報を取得する
    final replyUri = replyJson?['uri'];
    final replyCid = replyJson?['cid'];

    // 引用ポストの情報を取得する
    final quoteUri = quoteJson?['uri'];
    final quoteCid = quoteJson?['cid'];

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

    // 引用ポストの情報をembedに追加
    if (quoteUri != null && quoteCid != null) {
      embed = bsky.Embed.record(
        data: bsky.EmbedRecord(
          ref: bsky.StrongRef(
            cid: quoteCid,
            uri: bsky.AtUri.parse(quoteUri),
          ),
        ),
      );
    }

    // リプライ先がない場合は通常の投稿を行う
    if (replyUri == null) {
      await bluesky.feeds.createPost(
        text: blueskyText.value,
        facets: facets.map((e) => bsky.Facet.fromJson(e)).toList(),
        embed: embed,
      );
      return;
    }

    final strongRef =
        bsky.StrongRef(cid: replyCid, uri: bsky.AtUri.parse(replyUri));
    bsky.ReplyRef replyRef = bsky.ReplyRef(parent: strongRef, root: strongRef);

    await bluesky.feeds.createPost(
      text: blueskyText.value,
      reply: replyRef,
      facets: facets.map(bsky.Facet.fromJson).toList(),
      embed: embed,
    );
  }

  Widget _displayQuotedPost(Map<String, dynamic> post) {
    final quotedAuthor = post['author'];
    final createdAt = DateTime.parse(post['indexedAt']).toLocal();

    String languageCode = Localizations.localeOf(context).languageCode;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white30),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  quotedAuthor['displayName'] ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.0, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: Text(
                  '@${quotedAuthor['handle']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 12.0),
                ),
              ),
              Text(
                timeago.format(createdAt, locale: languageCode),
                style: const TextStyle(fontSize: 12.0),
                overflow: TextOverflow.clip,
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            post['record']['text'] ?? '',
            style: const TextStyle(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
