import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesRepository {
  SharedPreferences? _sharedPreferences;

  Future<bool> isLoggedIn() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString('id') != null;
  }

  Future<SharedPreferences> get sharedPreferences async {
    if (_sharedPreferences != null) return _sharedPreferences!;
    _sharedPreferences = await SharedPreferences.getInstance();
    return _sharedPreferences!;
  }

  Future<String> getId() async {
    return (await sharedPreferences).getString('id') ?? '';
  }

  Future<void> setId(String id) async {
    (await sharedPreferences).setString('id', id);
  }

  Future<String> getPassword() async {
    return (await sharedPreferences).getString('password') ?? '';
  }

  Future<void> setPassword(String password) async {
    (await sharedPreferences).setString('password', password);
  }
}
