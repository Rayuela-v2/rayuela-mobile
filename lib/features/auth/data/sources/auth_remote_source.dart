import 'package:dio/dio.dart';

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

  Future<Result<LoginResponseDto>> loginWithGoogle({
    required String credential,
    String? username,
  }) {
    return _api.request(
      (d) => d.post<Map<String, dynamic>>(
        ApiPaths.google,
        data: {
          'credential': credential,
          if (username != null) 'username': username,
        },
        options: _anonymous,
      ),
      parse: LoginResponseDto.fromJson,
    );
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
}
