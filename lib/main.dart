import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:skyclad/repository/shared_preferences_repository.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// 別スクリーン
import 'package:skyclad/view/timeline.dart';
import 'package:skyclad/view/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages("ja", timeago.JaMessages());

  final isLoggedIn = await SharedPreferencesRepository().isLoggedIn();

  runApp(
    ProviderScope(
      child: MaterialApp(
        title: 'Skyclad',
        theme: ThemeData.dark(),
        home: isLoggedIn ? const Timeline() : LoginScreen(),
        locale: WidgetsBinding.instance.platformDispatcher.locales.first,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'), // English
          Locale('ja'), // Japanese
        ],
      ),
    ),
  );
}

// プロバイダー
final isLoggedInProvider =
    StateNotifierProvider<IsLoggedInNotifier, bool>((ref) {
  return IsLoggedInNotifier();
});

final currentIndexProvider =
    StateNotifierProvider<CurrentIndexNotifier, int>((ref) {
  return CurrentIndexNotifier();
});

// Notifier
class IsLoggedInNotifier extends StateNotifier<bool> {
  IsLoggedInNotifier() : super(false);

  void setLoggedIn(bool value) {
    state = value;
  }
}

class CurrentIndexNotifier extends StateNotifier<int> {
  CurrentIndexNotifier() : super(0);

  void updateIndex(int newIndex) {
    state = newIndex;
  }
}
