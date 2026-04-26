import 'dart:io' show Platform;

/// Runtime configuration, populated from `--dart-define` or `--dart-define-from-file`.
///
/// Example:
///   flutter run --dart-define-from-file=.env.development
///
/// Never put secrets here. The app is shipped to user devices;
/// treat every value as public.
class Env {
  const Env._();

  static String get apiBaseUrl {
    const String defaultUrl = String.fromEnvironment('API_BASE_URL');
    if (defaultUrl.isNotEmpty && !defaultUrl.contains('localhost')) {
      return defaultUrl;
    }
    // Fallback for emulators
    final urlBase = defaultUrl.isNotEmpty ? defaultUrl : 'http://localhost:3000/v1';
    try {
      if (Platform.isAndroid) {
        return urlBase.replaceFirst('localhost', '10.0.2.2');
      }
    } catch (_) {}
    return urlBase;
  }

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  /// Gate for the refresh-token flow. Set to `true` once the backend ships
  /// `POST /auth/refresh` (see MIGRATION_PLAN §4.1).
  static const bool useRefreshToken = bool.fromEnvironment(
    'USE_REFRESH_TOKEN',
  );

  /// Toggles verbose HTTP logging in debug builds.
  static const bool logHttp = bool.fromEnvironment(
    'LOG_HTTP',
  );
}
