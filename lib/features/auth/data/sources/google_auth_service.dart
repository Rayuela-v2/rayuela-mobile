import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';

/// Thin wrapper around the `google_sign_in` plugin. Returns the Google
/// `idToken` that we POST to `/auth/google` (see backend
/// `verifyGoogleToken` — it strictly checks the token's `aud` against
/// `process.env.GOOGLE_CLIENT_ID`).
///
/// Important client-ID rules (Flutter `google_sign_in` v6):
///
///   • [iosClientId] — the **iOS** OAuth client ID. Passed as `clientId`.
///     iOS only.
///   • [webClientId]  — the **Web** OAuth client ID. Passed as
///     `serverClientId` on both platforms so the returned `idToken` has
///     `aud = webClientId` (which the backend's `GOOGLE_CLIENT_ID` should
///     also be set to).
///
/// You must NOT pass an Android-type OAuth client ID here. On Android the
/// plugin matches your app via package name + SHA-1 in Google Cloud.
/// Passing the Android client ID instead of the Web one is the classic
/// cause of `ApiException 10` (DEVELOPER_ERROR).
class GoogleAuthService {
  GoogleAuthService({
    String? iosClientId,
    String? webClientId,
  })  : _iosClientId = iosClientId,
        _webClientId = webClientId,
        _signIn = GoogleSignIn(
          clientId: iosClientId,
          serverClientId: webClientId,
          scopes: const ['email', 'profile', 'openid'],
        );

  final GoogleSignIn _signIn;
  // Stored for introspection / tests.
  // ignore: unused_field
  final String? _iosClientId;
  // ignore: unused_field
  final String? _webClientId;

  /// Triggers the native Google sign-in sheet and returns the resulting
  /// idToken. Returns:
  /// - `Success(idToken)` on a successful sign-in,
  /// - `Failure(GoogleSignInCancelledException())` when the user dismisses
  ///   the picker,
  /// - `Failure(...)` with a typed exception on any other error.
  Future<Result<String>> signIn() async {
    try {
      // Drop any previously-cached account so the user always sees the
      // chooser. Errors here are non-fatal.
      try {
        await _signIn.signOut();
      } catch (_) {}

      final account = await _signIn.signIn();
      if (account == null) {
        return const Failure<String>(GoogleSignInCancelledException());
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return Failure<String>(
          const ServerException(
            message:
                'Google did not return an ID token. Make sure '
                'GOOGLE_CLIENT_ID_WEB is set to a Web-type OAuth client ID '
                'and that the SHA-1 of this build is registered against '
                'the Android OAuth client in Google Cloud.',
          ),
        );
      }
      return Success<String>(idToken);
    } catch (e) {
      return Failure<String>(
        UnknownException(
          message: 'Google sign-in failed: $e',
          cause: e,
        ),
      );
    }
  }

  /// Signs out from the local Google session. Useful on logout so the
  /// next sign-in shows the account chooser instead of silently reusing
  /// the previous account.
  Future<void> signOut() async {
    try {
      await _signIn.signOut();
    } catch (_) {
      // Best-effort.
    }
  }
}
