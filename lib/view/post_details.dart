import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:skyclad/view/liked_by.dart';
import 'package:skyclad/view/reposted_by.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:linkify/linkify.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';

import 'package:skyclad/view/user_profile.dart';
import 'package:skyclad/view/create_post.dart';

class PostDetails extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;

  const PostDetails({required this.post, Key? key}) : super(key: key);

  @override
  ConsumerState<PostDetails> createState() => _PostDetailsState();
}

class _PostDetailsState extends ConsumerState<PostDetails> {
  Future<Map<String, dynamic>?>? _fetchPost;
  late Map<String, dynamic> _post;
  bool? _isLiked;
  bool? _isReposted;

  @override
  void initState() {
    super.initState();

    _fetchPost = _fetchPostDetails();
  }

  // 投稿の詳細を取得する
  Future<Map<String, dynamic>?> _fetchPostDetails() async {
    _post = widget.post;

    final String postUri = widget.post['uri'];
    final bluesky = await ref.read(blueskySessionProvider.future);
    final feeds =
        await bluesky.feeds.findPosts(uris: [bsky.AtUri.parse(postUri)]);
    final post = feeds.data.toJson()['posts'][0];

    _isLiked = post['viewer']['like'] != null;
    _isReposted = post['viewer']['repost'] != null;
    return post;
  }

  // 画像をダイアログで表示する
  void _showImageDialog(BuildContext context, List<String> imageUrls) {
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

  // 投稿の内容を表示する
  Widget _buildPostContent(Map<String, dynamic> post) {
    List<Widget> contentWidgets = [];

    // リプライを検出するための正規表現
    final replyPattern = RegExp(r'@([a-zA-Z0-9.]+)');

    // 投稿文をリンク付きの要素に分割する
    final elements = linkify(post['record']['text'],
        options: const LinkifyOptions(humanize: false));
    final List<InlineSpan> spans = [];

    // 投稿文の要素をウィジェットに変換する
    for (final element in elements) {
      if (element is TextElement) {
        // リプライを検出し、UserProfile画面に遷移するリンクを作成する
        final matches = replyPattern.allMatches(element.text);
        int lastIndex = 0;

        for (final match in matches) {
          final replyText = match.group(0);
          if (replyText != null) {
            spans.add(TextSpan(
              text: element.text.substring(lastIndex, match.start),
            ));
            spans.add(TextSpan(
              text: replyText,
              style: const TextStyle(color: Colors.blue),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UserProfileScreen(actor: replyText.substring(1)),
                    ),
                  );
                },
            ));
            lastIndex = match.end;
          }
        }

        spans.add(TextSpan(
          text: element.text.substring(lastIndex),
        ));
      } else if (element is UrlElement) {
        spans.add(TextSpan(
          text: element.text,
          style: const TextStyle(color: Colors.blue),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final messenger = ScaffoldMessenger.of(context);
              if (await canLaunchUrl(Uri.parse(element.url))) {
                await launchUrl(Uri.parse(element.url),
                    mode: LaunchMode.externalApplication);
              } else {
                messenger.showSnackBar(
                  const SnackBar(content: Text("リンクを開けませんでした。")),
                );
              }
            },
        ));
      }
    }

    contentWidgets.add(
      SelectableText.rich(
        TextSpan(
          children: spans,
          style: const TextStyle(fontSize: 16.0, color: Colors.white),
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
        GestureDetector(
          onTap: () => _showImageDialog(context, imageUrls),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: post['embed']['images']
                  .map<Widget>((image) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
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
                      ))
                  .toList(),
            ),
          ),
        ),
      );
    }

    // 引用投稿が含まれていたら追加する
    contentWidgets.add(_buildQuotedPost(post));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  // 引用投稿を表示する
  Widget _buildQuotedPost(Map<String, dynamic> post) {
    if (post['embed'] != null &&
        post['embed']['\$type'] == 'app.bsky.embed.record#view') {
      final quotedPost = post['embed']['record'];
      final quotedAuthor = quotedPost['author'];
      final createdAt = DateTime.parse(quotedPost['indexedAt']).toLocal();

      return InkWell(
        onTap: () async {
          final uri = quotedPost['uri'];

          final bluesky = await ref.read(blueskySessionProvider.future);
          final feeds =
              await bluesky.feeds.findPosts(uris: [bsky.AtUri.parse(uri)]);

          // 引用投稿先のJSONを取得する
          final jsonFeed = feeds.data.toJson()['posts'][0];

          // ignore: use_build_context_synchronously
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetails(post: jsonFeed),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white38),
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
                    timeago.format(createdAt, locale: "ja"),
                    style: const TextStyle(fontSize: 12.0),
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              Text(
                quotedPost['value']['text'] ?? '',
                style: const TextStyle(fontSize: 14.0),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // リプライ先の投稿の内容を表示する
  Future<Widget> _buildParentPost(
      BuildContext context, Map<String, dynamic> post) async {
    if (post['record']['reply'] == null) {
      return const SizedBox.shrink();
    }

    final parentUri = post['record']['reply']['parent']['uri'];

    final bluesky = await ref.read(blueskySessionProvider.future);
    final feeds =
        await bluesky.feeds.findPosts(uris: [bsky.AtUri.parse(parentUri)]);

    // 引用投稿先のJSONを取得する
    final parent = feeds.data.toJson()['posts'][0];

    if (parent == null) {
      return const SizedBox.shrink();
    }

    final author = parent['author'];
    final content = parent['record']['text'];
    final createdAt = DateTime.parse(parent['indexedAt']).toLocal();

    DateFormat format = DateFormat('yyyy/MM/dd HH:mm');
    String dateStr = format.format(createdAt);

    return InkWell(
      onTap: () {
        // 投稿詳細画面への遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetails(
              post: parent,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  // ユーザー詳細画面への遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        actor: author['handle'],
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 24.0,
                  backgroundImage: NetworkImage(author['avatar'] ?? ''),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                // 追加
                child: Text(
                  '${author['displayName'] ?? ''} (@${author['handle']})',
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5.0),
          Text(
            content,
            style: const TextStyle(fontSize: 14.0, color: Colors.white),
          ),
          const SizedBox(height: 5.0),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 12.0, color: Colors.white38),
          ),
          const SizedBox(height: 15.0),
          const Divider(color: Colors.white38, height: 1.0),
          const SizedBox(height: 15.0)
        ],
      ),
    );
  }

  // リプライ先のスレッドの内容を表示する
  Future<Widget> _buildThreadPost(
      BuildContext context, Map<String, dynamic> post) async {
    final recordUri = post['uri'];

    final bluesky = await ref.read(blueskySessionProvider.future);
    final thread =
        await bluesky.feeds.findPostThread(uri: bsky.AtUri.parse(recordUri));

    // 引用投稿先のJSONを取得する
    final replies = thread.data.toJson()['thread']['replies'];

    if (replies == null) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      itemCount: replies.length,
      itemBuilder: (context, index) {
        final feed = replies[index];
        final post = feed['post'];
        final author = post['author'];
        final createdAt = DateTime.parse(post['indexedAt']).toLocal();

        DateFormat format = DateFormat('yyyy/MM/dd HH:mm');
        String dateStr = format.format(createdAt);

        return Column(
          children: [
            if (index != 0) // この行を追加
              const Divider(color: Colors.white38, height: 1.0), // この行を追加
            InkWell(
              onTap: () {
                // 投稿詳細画面への遷移
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetails(
                      post: post,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white38, height: 1.0),
                  const SizedBox(height: 15.0),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // ユーザー詳細画面への遷移
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                actor: author['handle'],
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 24.0,
                          backgroundImage: NetworkImage(author['avatar'] ?? ''),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        // 追加
                        child: Text(
                          '${author['displayName'] ?? ''} (@${author['handle']})',
                          style: const TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5.0),
                  Text(
                    post['record']['text'],
                    style: const TextStyle(fontSize: 14.0, color: Colors.white),
                  ),
                  const SizedBox(height: 15.0),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 15.0)
                ],
              ),
            )
          ],
        );
      },
      shrinkWrap: true, // 追加
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchPost,
      builder: (BuildContext context,
          AsyncSnapshot<Map<String, dynamic>?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          final _post = snapshot.data!;
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder(
                      future: _buildParentPost(context, _post),
                      builder: (BuildContext context,
                          AsyncSnapshot<Widget> snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasData) {
                            return snapshot.data!;
                          } else {
                            return const SizedBox.shrink();
                          }
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(
                                  actor: _post['author']['handle'],
                                ),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            backgroundImage:
                                NetworkImage(_post['author']['avatar'] ?? ''),
                            radius: 20,
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author['displayName'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold),
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
                    _buildPostContent(_post),
                    const SizedBox(height: 15.0),
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 14.0, color: Colors.white38),
                    ),
                    const SizedBox(height: 10.0),
                    const Divider(
                        height: 1, thickness: 1, color: Colors.white12),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.reply),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreatePostScreen(
                                    replyJson: _post,
                                  ),
                                ),
                              );
                            },
                          ),
                          Column(children: [
                            IconButton(
                              icon: _isReposted!
                                  ? const Icon(Icons.cached)
                                  : const Icon(Icons.cached_outlined),
                              color: _isReposted! ? Colors.green : null,
                              onPressed: () async {
                                setState(() {
                                  _isReposted = !_isReposted!;
                                  if (_isReposted!) {
                                    _post['repostCount'] += 1;
                                  } else {
                                    _post['repostCount'] -= 1;
                                  }
                                });

                                final bluesky = await ref
                                    .read(blueskySessionProvider.future);

                                if (isReposted) {
                                  // リポストを取り消し
                                  await bluesky.repositories.deleteRecord(
                                    uri: bsky.AtUri.parse(
                                        _post['viewer']['repost']),
                                  );
                                } else {
                                  // リポスト処理
                                  final repostedRecord =
                                      await bluesky.feeds.createRepost(
                                    cid: _post['cid'],
                                    uri: bsky.AtUri.parse(_post['uri']),
                                  );
                                  _post['viewer']['repost'] = {
                                    'uri': repostedRecord.data.uri
                                  };
                                }
                              },
                            ),
                          ]),
                          Column(children: [
                            IconButton(
                              icon: _isLiked!
                                  ? const Icon(Icons.favorite)
                                  : const Icon(Icons.favorite_border),
                              color: _isLiked! ? Colors.red : null,
                              onPressed: () async {
                                setState(() {
                                  _isLiked = !_isLiked!;
                                  if (_isLiked!) {
                                    _post['likeCount'] += 1;
                                  } else {
                                    _post['likeCount'] -= 1;
                                  }
                                });

                                final bluesky = await ref
                                    .read(blueskySessionProvider.future);

                                if (isLiked) {
                                  // いいねを取り消し
                                  await bluesky.repositories.deleteRecord(
                                    uri: bsky.AtUri.parse(
                                        _post['viewer']['like']),
                                  );
                                } else {
                                  // いいね処理
                                  final likedRecord =
                                      await bluesky.feeds.createLike(
                                    cid: _post['cid'],
                                    uri: bsky.AtUri.parse(_post['uri']),
                                  );
                                  _post['viewer']
                                      ['like'] = {'uri': likedRecord.data.uri};
                                }
                              },
                            ),
                          ]),
                          Column(children: [
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz),
                              onSelected: (value) {
                                if (value == "report") {
                                  // TODO: 投稿を報告する処理をここに書く
                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("投稿を報告しました"),
                                      backgroundColor: Colors.white,
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: "report",
                                  child: ListTile(
                                    title: Text("投稿を報告する"),
                                  ),
                                ),
                              ],
                            ),
                          ]),
                        ]),
                    const Divider(
                        height: 1, thickness: 1, color: Colors.white12),
                    const SizedBox(height: 10.0),
                    Row(
                      children: [
                        const SizedBox(width: 30.0),
                        Row(
                          children: [
                            const SizedBox(width: 10.0),
                            GestureDetector(
                              onTap: () {
                                // リポストの数字がタップされたときの処理をここに追加します
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RepostedByScreen(uri: _post['uri']),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  Text(
                                    _post['repostCount'].toString(),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2.0),
                                  const Text(
                                    'リポスト',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white60),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 43.0),
                            const SizedBox(
                              height: 50,
                              child: VerticalDivider(
                                  width: 1,
                                  thickness: 1,
                                  color: Colors.white30),
                            ),
                            const SizedBox(width: 43.0),
                            GestureDetector(
                              onTap: () {
                                // いいねの数字がタップされたときの処理をここに追加します
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        LikedByScreen(uri: _post['uri']),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  Text(_post['likeCount'].toString(),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2.0),
                                  const Text('いいね',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white60)),
                                ],
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    FutureBuilder(
                      future: _buildThreadPost(context, _post),
                      builder: (BuildContext context,
                          AsyncSnapshot<Widget> snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasData) {
                            return snapshot.data!;
                          } else {
                            return const SizedBox.shrink();
                          }
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return const Text("データがありません");
        }
      },
    );
  }
}
