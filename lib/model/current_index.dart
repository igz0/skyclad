import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentIndexProvider =
    StateNotifierProvider<CurrentIndexNotifier, int>((ref) {
  return CurrentIndexNotifier();
});

class CurrentIndexNotifier extends StateNotifier<int> {
  CurrentIndexNotifier() : super(0);

  void updateIndex(int newIndex) {
    state = newIndex;
  }
}
