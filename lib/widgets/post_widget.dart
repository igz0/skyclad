import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:skyclad/view/user_profile.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:skyclad/providers/providers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// 別スクリーン
import 'package:skyclad/view/post_details.dart';

// 投稿の詳細を取得するための FutureProvider
final quotedPostProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, uri) async {
  final bluesky = await ref.read(blueskySessionProvider.future);
  final feeds = await bluesky.feeds.findPosts(uris: [bsky.AtUri.parse(uri)]);

  // 引用投稿先のJSONを取得する
  final jsonFeed = feeds.data.toJson()['posts'][0];

  return jsonFeed;
});

class PostWidget extends ConsumerWidget {
  final Map<String, dynamic> post;

  const PostWidget({required this.post, Key? key}) : super(key: key);

  // 投稿のウィジェットを作成する
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<Widget> contentWidgets = [];
    List<InlineSpan> spans = [];

    final text = post['record']?['text'] ?? '';

    // facetsを取得する。facetsにはリンクやメンションなどの情報が含まれる
    final facets = post['record']['facets'] as List? ?? [];

    // 投稿文をバイトの形式でエンコードする
    final facetBytes = utf8.encode(text);
    var lastFacetEndByte = 0;

    // 各facetに対する処理
    for (final facet in facets) {
      for (final feature in facet['features']) {
        final byteStart = facet['index']['byteStart'];

        // バイトの範囲が投稿文の範囲を超えていたら、範囲を投稿文の範囲に合わせる
        final byteEnd = min<int>(facet['index']['byteEnd'], facetBytes.length);

        // 関連するテキスト部分をバイトからデコードする
        final facetText = utf8.decode(
          facetBytes.sublist(
            byteStart,
            byteEnd,
          ),
        );

        // 前のfacetの終了位置から、現在のfacetの開始位置までのテキストを追加する
        if (facet['index']['byteStart'] > lastFacetEndByte) {
          spans.add(
            TextSpan(
                text: utf8.decode(facetBytes.sublist(
                    lastFacetEndByte, facet['index']['byteStart']))),
          );
        }

        // facetがリンクの場合の処理
        if (feature['\$type'] == 'app.bsky.richtext.facet#link') {
          spans.add(
            TextSpan(
              text: facetText,
              style: const TextStyle(color: Colors.blue),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (await canLaunchUrl(Uri.parse(feature['uri']))) {
                    await launchUrl(Uri.parse(feature['uri']),
                        mode: LaunchMode.externalApplication);
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text(
                          // ignore: use_build_context_synchronously
                          AppLocalizations.of(context)!.errorFailedToOpenUrl)),
                    );
                  }
                },
            ),
          );
        }

        // facetがメンションの場合の処理
        else if (feature['\$type'] == 'app.bsky.richtext.facet#mention') {
          spans.add(
            TextSpan(
              text: facetText,
              style: const TextStyle(color: Colors.blue),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UserProfileScreen(actor: feature['did']),
                    ),
                  );
                },
            ),
          );
        }
        // その他のfacetの場合の処理
        else {
          spans.add(TextSpan(text: facetText));
        }

        lastFacetEndByte = facet['index']['byteEnd'];
      }
    }

    // 最後のfacet以降のテキストを追加する
    spans
        .add(TextSpan(text: utf8.decode(facetBytes.sublist(lastFacetEndByte))));

    // spansに格納されたテキストスパンをリッチテキストウィジェットとしてcontentWidgetsリストに追加する
    contentWidgets.add(
      RichText(
        text: TextSpan(
          children: spans,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
      ),
    );

    // 投稿に画像が含まれていたら追加する
    if (post['embed'] != null &&
        post['embed']['\$type'] == 'app.bsky.embed.images#view') {
      contentWidgets.add(const SizedBox(height: 10.0));

      // 画像ウィジェットを作成する
      List<String> imageUrls = post['embed']['images']
          .map<String>((dynamic image) => image['fullsize'] as String)
          .toList();

      // タップで画像ダイアログを表示する
      contentWidgets.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                post['embed']['images'].asMap().entries.map<Widget>((entry) {
              int index = entry.key;
              dynamic image = entry.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, imageUrls, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      image['thumb'],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    // 引用投稿が含まれていたら追加する
    contentWidgets.add(_buildQuotedPost(context, ref, post));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

// 引用投稿のウィジェットを作成する
  Widget _buildQuotedPost(
      BuildContext context, WidgetRef ref, Map<String, dynamic> post) {
    if (post['embed'] != null &&
        post['embed']['\$type'] == 'app.bsky.embed.record#view') {
      final quotedPost = post['embed']['record'];
      final quotedAuthor = quotedPost['author'];
      final createdAt = DateTime.parse(post['indexedAt']).toLocal();

      String languageCode = Localizations.localeOf(context).languageCode;
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  final postProvider =
                      ref.watch(quotedPostProvider(quotedPost['uri']));
                  return postProvider.when(
                    data: (data) => PostDetails(post: data),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, stack) =>
                        Center(child: Text('Error: ${e.toString()}')),
                  );
                },
              ),
            ),
          );
        },
        child: Container(
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
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12.0),
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
                quotedPost['value']['text'] ?? '',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // 画像をダイアログで表示する
  void _showImageDialog(
      BuildContext context, List<String> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          insetPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              MediaQuery(
                data: MediaQuery.of(context),
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.vertical,
                  onDismissed: (direction) {
                    Navigator.pop(context);
                  },
                  dismissThresholds: const {
                    DismissDirection.vertical: 0.2,
                  },
                  child: SizedBox(
                    width: screenWidth,
                    height: screenHeight,
                    child: Swiper(
                      itemBuilder: (BuildContext context, int index) {
                        return Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error),
                            );
                          },
                        );
                      },
                      itemCount: imageUrls.length,
                      loop: false,
                      index: initialIndex,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
