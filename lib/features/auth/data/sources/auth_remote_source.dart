import 'package:dio/dio.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../models/auth_dtos.dart';

/// All HTTP calls for auth live here. Every method returns a [Result]
/// so callers can pattern-match success/failure.
class AuthRemoteSource {
  const AuthRemoteSource(this._api);

  final ApiClient _api;

  // Login endpoints do not need (and cannot attach) a bearer token.
  static final Options _anonymous = Options(extra: const {'anonymous': true});

  Future<Result<LoginResponseDto>> login(LoginRequestDto req) {
    return _api.request(
      (d) => d.post<Map<String, dynamic>>(
        ApiPaths.login,
        data: req.toJson(),
        options: _anonymous,
      ),
      parse: LoginResponseDto.fromJson,
    );
  }

  /// POST /auth/google. Distinct from [login] because the backend can
  /// reply with a structured 400 — `requiresUsername: true` plus a
  /// `suggestedUsername` — when the Google account has no Rayuela
  /// counterpart yet. We surface that as
  /// [GoogleSignupRequiresUsernameException] so the UI can collect a
  /// username and retry, instead of losing the info inside a generic
  /// [ValidationException].
  Future<Result<LoginResponseDto>> loginWithGoogle({
    required String credential,
    String? username,
  }) async {
    try {
      final response = await _api.raw.post<Map<String, dynamic>>(
        ApiPaths.google,
        data: {
          'credential': credential,
          if (username != null) 'username': username,
        },
        options: _anonymous,
      );
      return Success(LoginResponseDto.fromJson(response.data));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 400 && data is Map) {
        final requires = data['requiresUsername'];
        if (requires == true || requires == 'true') {
          final suggested = data['suggestedUsername'];
          return Failure<LoginResponseDto>(
            GoogleSignupRequiresUsernameException(
              message: data['message']?.toString() ??
                  'Username is required for new Google signup',
              suggestedUsername: suggested is String ? suggested : null,
              cause: e,
            ),
          );
        }
      }
      return Failure<LoginResponseDto>(_api.mapDioError(e));
    } catch (e) {
      return Failure<LoginResponseDto>(
        UnknownException(message: e.toString(), cause: e),
      );
    }
  }

  Future<Result<void>> register(RegisterRequestDto req) {
    return _api.request<void>(
      (d) => d.post<Object?>(
        ApiPaths.register,
        data: req.toJson(),
        options: _anonymous,
      ),
      parse: (_) {},
    );
  }

  Future<Result<UserDto>> fetchMe() {
    return _api.request(
      (d) => d.get<Map<String, dynamic>>(ApiPaths.me),
      parse: UserDto.fromJson,
    );
  }

  Future<Result<void>> forgotPassword(String email) {
    return _api.request<void>(
      (d) => d.post<Object?>(
        ApiPaths.forgotPassword,
        data: {'email': email},
        options: _anonymous,
      ),
      parse: (_) {},
    );
  }

  Future<Result<void>> logout(String refreshToken) {
    return _api.request<void>(
      (d) => d.post<Object?>(
        ApiPaths.logout,
        data: {'refreshToken': refreshToken},
      ),
      parse: (_) {},
    );
  }
}
