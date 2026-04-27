import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../data/sources/google_auth_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';

/// Union of possible auth states the app can be in.
sealed class AuthState {
  const AuthState();
}

/// Initial value before the splash has decided.
final class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

final class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated(this.user);
  final AuthUser user;
}

final class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated({this.reason});
  final String? reason;
}

/// App-wide auth state. Read by the router, mutated by screens.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(googleAuthServiceProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, this._google) : super(const AuthStateInitial());

  final AuthRepository _repo;
  final GoogleAuthService _google;

  /// Called from the splash screen on boot.
  Future<void> bootstrap() async {
    final hasSession = await _repo.hasValidSession();
    if (!hasSession) {
      state = const AuthStateUnauthenticated();
      return;
    }
    final res = await _repo.fetchCurrentUser();
    state = res.fold(
      onSuccess: AuthStateAuthenticated.new,
      onFailure: (e) => AuthStateUnauthenticated(reason: e.message),
    );
  }

  /// Login with username + password. Returns the typed exception on failure
  /// so the screen can surface field errors.
  Future<AppException?> login({
    required String username,
    required String password,
  }) async {
    final res = await _repo.login(username: username, password: password);
    return switch (res) {
      Success<AuthUser>(:final value) => () {
          state = AuthStateAuthenticated(value);
          return null;
        }(),
      Failure<AuthUser>(:final error) => error,
    };
  }

  /// Cached idToken from the most recent `_google.signIn()`. Lets the
  /// "username required" retry hit the backend without re-prompting the
  /// user with the native sheet.
  String? _lastGoogleCredential;

  /// Drives the Google sign-in sheet then trades the resulting idToken for
  /// a Rayuela session via `POST /auth/google`. Returns:
  /// - `null` on success (state transitions to authenticated),
  /// - a [GoogleSignupRequiresUsernameException] when the backend says the
  ///   Google account has no Rayuela counterpart and needs a username
  ///   (call [completeGoogleSignup] with the chosen username to retry),
  /// - a [GoogleSignInCancelledException] when the user dismissed the
  ///   sheet, or another [AppException] on failure.
  Future<AppException?> loginWithGoogle() async {
    final googleResult = await _google.signIn();
    switch (googleResult) {
      case Success<String>(:final value):
        _lastGoogleCredential = value;
        return _exchangeGoogleCredential(credential: value);
      case Failure<String>(:final error):
        return error;
    }
  }

  /// Retries `POST /auth/google` with the previously-cached credential
  /// plus the username the user just picked. Returns the same shape as
  /// [loginWithGoogle].
  Future<AppException?> completeGoogleSignup({required String username}) async {
    final cached = _lastGoogleCredential;
    if (cached == null || cached.isEmpty) {
      // Should never happen — the UI only surfaces the username prompt
      // after a successful signIn(). Defensive fallback: re-run the flow.
      return loginWithGoogle();
    }
    return _exchangeGoogleCredential(credential: cached, username: username);
  }

  Future<AppException?> _exchangeGoogleCredential({
    required String credential,
    String? username,
  }) async {
    final res = await _repo.loginWithGoogle(
      credential: credential,
      username: username,
    );
    return switch (res) {
      Success<AuthUser>(:final value) => () {
          state = AuthStateAuthenticated(value);
          _lastGoogleCredential = null;
          return null;
        }(),
      Failure<AuthUser>(:final error) => error,
    };
  }

  Future<AppException?> register({
    required String completeName,
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await _repo.register(
      completeName: completeName,
      username: username,
      email: email,
      password: password,
    );
    return switch (res) {
      Success<void>() => null,
      Failure<void>(:final error) => error,
    };
  }

  Future<void> logout() async {
    await _repo.logout();
    // Best-effort: drop any cached Google account so the next sign-in
    // shows the chooser instead of silently re-authenticating.
    await _google.signOut();
    state = const AuthStateUnauthenticated();
  }

  /// Re-fetch the current user from `/user`. Called after a subscription
  /// change so the dashboard's per-project gameProfile overlay updates
  /// without forcing a full re-login. No-ops when unauthenticated.
  Future<void> refreshUser() async {
    if (state is! AuthStateAuthenticated) return;
    final res = await _repo.fetchCurrentUser();
    state = res.fold(
      onSuccess: AuthStateAuthenticated.new,
      // Keep the previous state on failure — refreshing is best-effort.
      onFailure: (_) => state,
    );
  }

  /// Called by the refresh interceptor when the refresh token fails.
  void forceSignOut() {
    state = const AuthStateUnauthenticated(reason: 'Session expired');
  }
}
