import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../locale/locale_controller.dart';

/// SharedPreferences key for the saved theme mode (`light` / `dark`).
const String kThemePrefsKey = 'app.theme.mode';

/// User-chosen theme. Defaults to [ThemeMode.system] until the user toggles.
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static ThemeMode _read(SharedPreferences prefs) {
    switch (prefs.getString(kThemePrefsKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(kThemePrefsKey, mode.name);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController(ref.watch(sharedPreferencesProvider));
});
