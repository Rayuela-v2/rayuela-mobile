import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../../core/storage/secure_token_store.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/auth_dtos.dart';
import '../sources/auth_remote_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteSource remote,
    required SecureTokenStore tokens,
  })  : _remote = remote,
        _tokens = tokens;

  final AuthRemoteSource _remote;
  final SecureTokenStore _tokens;

  @override
  Future<Result<AuthUser>> login({
    required String username,
    required String password,
  }) async {
    final tokenResult = await _remote.login(
      LoginRequestDto(username: username, password: password),
    );
    return tokenResult.fold(
      onSuccess: _completeLogin,
      onFailure: (e) async => Failure<AuthUser>(e),
    );
  }

  @override
  Future<Result<AuthUser>> loginWithGoogle({
    required String credential,
    String? username,
  }) async {
    final tokenResult = await _remote.loginWithGoogle(
      credential: credential,
      username: username,
    );
    return tokenResult.fold(
      onSuccess: _completeLogin,
      onFailure: (e) async => Failure<AuthUser>(e),
    );
  }

  Future<Result<AuthUser>> _completeLogin(LoginResponseDto token) async {
    await _tokens.saveTokens(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
    );
    final meResult = await _remote.fetchMe();
    return meResult.fold(
      onSuccess: (dto) async {
        await _tokens.saveTokens(
          accessToken: token.accessToken,
          refreshToken: token.refreshToken,
          userId: dto.id,
        );
        return Success(dto.toEntity());
      },
      onFailure: (e) async {
        // Token saved but profile fetch failed; undo to avoid a zombie session.
        await _tokens.clear();
        return Failure<AuthUser>(e);
      },
    );
  }

  @override
  Future<Result<void>> register({
    required String completeName,
    required String username,
    required String email,
    required String password,
  }) {
    return _remote.register(
      RegisterRequestDto(
        completeName: completeName,
        username: username,
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<Result<AuthUser>> fetchCurrentUser() async {
    final res = await _remote.fetchMe();
    return res.fold(
      onSuccess: (dto) => Success<AuthUser>(dto.toEntity()),
      onFailure: (e) {
        if (e is UnauthorizedException) {
          // Token is invalid — drop it.
          _tokens.clear();
        }
        return Failure<AuthUser>(e);
      },
    );
  }

  @override
  Future<Result<void>> forgotPassword(String email) =>
      _remote.forgotPassword(email);

  @override
  Future<void> logout() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken != null) {
      await _remote.logout(refreshToken);
    }
    await _tokens.clear();
  }

  @override
  Future<bool> hasValidSession() async {
    final token = await _tokens.readAccessToken();
    return token != null && token.isNotEmpty;
  }
}
