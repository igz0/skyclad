import 'package:bluesky/bluesky.dart' as bsky;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skyclad/providers/providers.dart';

import 'package:skyclad/view/timeline.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends ConsumerWidget {
  LoginScreen({Key? key}) : super(key: key);

  static const _defaultService = 'bsky.social';

  final _serviceController = TextEditingController(text: _defaultService);
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.blue[600],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _serviceController,
                decoration: const InputDecoration(
                  labelText: 'Service',
                  hintText: _defaultService,
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _usernameController, // 追加
                decoration: const InputDecoration(
                  labelText: 'Username or email address',
                  hintText: 'Enter your username(e.g. test.bsky.social)',
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController, // 追加
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'App Password',
                  hintText: 'Enter your app password',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: IconButton(
                      onPressed: () => launchUrl(
                        Uri.https('bsky.app', '/settings/app-passwords'),
                      ),
                      icon: Icon(
                        Icons.help_outline,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: () async {
                  // 入力された認証情報を取得
                  String service = _serviceController.text.trim();
                  String id = _usernameController.text.trim();
                  final password = _passwordController.text.trim();

                  if (service.isEmpty) {
                    //* サービスが未入力の場合は"bsky.social"を強制する
                    service = _serviceController.text = _defaultService;
                  }

                  if (!id.contains('.')) {
                    //* ドメインの入力を省略可能にする。
                    id += '.$service';
                  }

                  // ログイン処理を実行
                  try {
                    if (!bsky.isValidAppPassword(password)) {
                      //! App Passwordの使用を強制する。
                      throw Exception('Not a valid app password.');
                    }

                    await ref
                        .read(loginStateProvider.notifier)
                        .login(service, id, password);
                    // ログイン成功後の画面遷移を行います
                    // ignore: use_build_context_synchronously
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const Timeline()),
                    );
                  } catch (e) {
                    // ログインに失敗した場合の処理
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
