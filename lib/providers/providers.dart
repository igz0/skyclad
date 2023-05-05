import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:skyclad/view/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyclad/repository/shared_preferences_repository.dart';

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>(
        (ref) => UserProfileNotifier(ref));

final blueskySessionProvider = FutureProvider<bsky.Bluesky>((ref) async {
  final sharedPreferencesRepository =
      ref.read(sharedPreferencesRepositoryProvider);
  final id = await sharedPreferencesRepository.getId();
  final password = await sharedPreferencesRepository.getPassword();

  final session = await bsky.createSession(
    identifier: id,
    password: password,
  );
  final bluesky = bsky.Bluesky.fromSession(session.data);
  return bluesky;
});

final loginStateProvider =
    StateNotifierProvider<LoginStateNotifier, bool>((ref) {
  return LoginStateNotifier();
});

class LoginStateNotifier extends StateNotifier<bool> {
  LoginStateNotifier() : super(false);

  Future<void> login(String id, String password) async {
    try {
      // TODO: セッション情報をRiverpodで管理する
      await bsky.createSession(
        identifier: id,
        password: password,
      );
      // ログインに成功したら、IDとパスワードを保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('id', id);
      await prefs.setString('password', password);

      state = true;
    } catch (e) {
      // ログインに失敗した場合の処理
      throw Exception('Login failed.');
    }
  }
}

final sharedPreferencesRepositoryProvider =
    Provider<SharedPreferencesRepository>((ref) {
  return SharedPreferencesRepository();
});
