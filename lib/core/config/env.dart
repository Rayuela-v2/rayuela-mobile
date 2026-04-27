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

  // ---------------------------------------------------------------------
  // Google Sign-In
  //
  // The `google_sign_in` plugin treats Android, iOS and Web differently:
  //
  //   • Android — DO NOT pass an Android-type OAuth client ID anywhere in
  //     code. Android matches your app via package name + SHA-1 fingerprint
  //     registered against the Android client in Google Cloud. To get back
  //     an `idToken` we can hand to the backend, we MUST pass a *Web*
  //     OAuth client ID as `serverClientId`. Passing the Android client ID
  //     instead causes ApiException 10 (DEVELOPER_ERROR).
  //
  //   • iOS — pass the iOS OAuth client ID as `clientId`. Passing the Web
  //     client ID as `serverClientId` is also useful so the resulting
  //     `serverAuthCode` (and audience handling) matches the Android side.
  //
  // The backend's `process.env.GOOGLE_CLIENT_ID` should equal the Web
  // client ID, since `verifyGoogleToken` strictly checks `payload.aud`.
  // ---------------------------------------------------------------------

  /// iOS OAuth client ID. Passed to `GoogleSignIn` as `clientId`.
  static const String googleClientIdIos = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_IOS',
  );

  /// Web OAuth client ID. Passed to `GoogleSignIn` as `serverClientId` on
  /// **both** Android and iOS so we get back an `idToken` whose `aud`
  /// matches what the backend verifies.
  static const String googleClientIdWeb = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_WEB',
  );

  /// Android OAuth client ID — kept here for documentation only. The
  /// plugin doesn't accept it, but Google Cloud needs it (with the
  /// build's SHA-1) for Android sign-in to work at all.
  static const String googleClientIdAndroid = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_ANDROID',
  );

  /// Whether `--dart-define`s for Google sign-in were provided. Requires
  /// the Web client ID always; the iOS client ID only when running on iOS.
  static bool get isGoogleSignInConfigured {
    if (googleClientIdWeb.isEmpty) return false;
    try {
      if (Platform.isIOS) return googleClientIdIos.isNotEmpty;
    } catch (_) {
      // Platform unavailable (e.g. tests on the VM) — fall through.
    }
    return true;
  }

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
