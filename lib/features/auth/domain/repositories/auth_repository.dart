import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';

/// Abstract contract the UI layer depends on.
abstract class AuthRepository {
  Future<Result<AuthUser>> login({
    required String username,
    required String password,
  });

  Future<Result<AuthUser>> loginWithGoogle({
    required String credential,
    String? username,
  });

  Future<Result<void>> register({
    required String completeName,
    required String username,
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> fetchCurrentUser();

  /// Patch the signed-in user's own profile. Null arguments are left
  /// untouched server-side.
  Future<Result<AuthUser>> updateProfile({
    String? completeName,
    String? description,
    String? profileImage,
  });

  /// Last profile we successfully fetched, or null. Lets the splash screen
  /// keep an offline user signed in instead of showing the login screen.
  Future<AuthUser?> cachedUser();

  Future<Result<void>> forgotPassword(String email);

  Future<void> logout();

  /// Whether we have a persisted access token. Used by the splash screen.
  Future<bool> hasValidSession();
}
