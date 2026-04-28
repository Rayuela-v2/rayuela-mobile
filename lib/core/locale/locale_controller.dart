import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of languages the user can pick from at runtime. Mirrors
/// `supportedLocales` declared on the [MaterialApp] and the ARB files we
/// ship under `lib/l10n/`.
///
/// Keep this list in sync with `lib/l10n/app_localizations.dart` —
/// `LocaleController.setLocale` validates against the language codes here
/// before persisting them.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('en'),
  Locale('es'),
  Locale('pt'),
];

/// SharedPreferences key for the saved language code.
@visibleForTesting
const String kLocalePrefsKey = 'app.locale.languageCode';

/// User-controlled language for the app. `null` means "follow the system
/// locale" (the default after a fresh install). Picking a specific locale
/// from the language picker writes through to SharedPreferences so the
/// next launch comes back in the same language.
class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._prefs) : super(_readSaved(_prefs));

  final SharedPreferences _prefs;

  static Locale? _readSaved(SharedPreferences prefs) {
    final code = prefs.getString(kLocalePrefsKey);
    if (code == null || code.isEmpty) return null;
    final match = kSupportedLocales
        .where((l) => l.languageCode == code)
        .cast<Locale?>()
        .firstWhere((_) => true, orElse: () => null);
    return match;
  }

  /// Switch to [locale]. Pass `null` to clear the override and fall back
  /// to the system locale. Unsupported locales are silently ignored.
  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(kLocalePrefsKey);
      state = null;
      return;
    }
    final isSupported =
        kSupportedLocales.any((l) => l.languageCode == locale.languageCode);
    if (!isSupported) return;
    await _prefs.setString(kLocalePrefsKey, locale.languageCode);
    state = locale;
  }
}

/// Holds the [SharedPreferences] instance. Overridden in `bootstrap.dart`
/// so feature code can stay ignorant of construction.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

/// App-wide locale override. `null` means "use the system locale".
final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController(ref.watch(sharedPreferencesProvider));
});
