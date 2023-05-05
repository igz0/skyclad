import 'package:flutter_riverpod/flutter_riverpod.dart';

final isLoggedInProvider =
    StateNotifierProvider<IsLoggedInNotifier, bool>((ref) {
  return IsLoggedInNotifier();
});

class IsLoggedInNotifier extends StateNotifier<bool> {
  IsLoggedInNotifier() : super(false);

  void setLoggedIn(bool value) {
    state = value;
  }
}
