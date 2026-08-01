import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'api_paths.dart';

/// On a 401, tries to refresh the access token once and replay the original
/// request.
///
/// The session is dropped **only** when the backend actively rejects the
/// refresh token (401/403 from `/auth/refresh`) or when there is no refresh
/// token at all. Every other failure — offline, timeout, 5xx — leaves the
/// tokens on disk and surfaces the original error, because a flaky network
/// is not a reason to sign the user out.
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required Dio dio,
    required SecureTokenStore tokens,
    required this.onAuthFailure,
  })  : _dio = dio,
        _tokens = tokens;

  final Dio _dio;
  final SecureTokenStore _tokens;
  final FutureOr<void> Function() onAuthFailure;

  /// Guards against multiple concurrent refreshes when a burst of requests
  /// gets rejected with 401 at the same time.
  Future<String?>? _inFlightRefresh;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final request = err.requestOptions;
    final alreadyRetried = request.extra['_retried'] == true;

    final is401 = response?.statusCode == 401;
    final isRefreshCall = request.path.endsWith(ApiPaths.refresh);

    if (!is401 || alreadyRetried || isRefreshCall) {
      handler.next(err);
      return;
    }

    try {
      final newAccess = await (_inFlightRefresh ??= _refresh());
      _inFlightRefresh = null;

      if (newAccess == null) {
        // No refresh token on disk — there is nothing left to recover.
        await _failAndLogout();
        handler.next(err);
        return;
      }

      // Replay the original request with the new token.
      request.headers['Authorization'] = 'Bearer $newAccess';
      request.extra['_retried'] = true;
      final retryResponse = await _dio.fetch<dynamic>(request);
      handler.resolve(retryResponse);
    } on DioException catch (e) {
      _inFlightRefresh = null;
      // Only a real rejection of the refresh token ends the session. A
      // connection error / timeout / 5xx means "try again later", and
      // wiping the tokens there is what used to log users out at random.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await _failAndLogout();
      }
      handler.next(e);
    } catch (_) {
      _inFlightRefresh = null;
      handler.next(err);
    }
  }

  /// Returns the new access token, or null only when there is no refresh
  /// token to spend — the one case where signing out is the right answer.
  Future<String?> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;

    final response = await _dio.post<Map<String, dynamic>>(
      ApiPaths.refresh,
      data: {'refreshToken': refresh},
      options: Options(extra: {'anonymous': true}),
    );

    // The backend answers in snake_case (`access_token`); accept camelCase
    // too, the way LoginResponseDto does, so one casing change can't take
    // every session down again.
    final data = response.data;
    final newAccess =
        (data?['accessToken'] ?? data?['access_token']) as String?;
    final newRefresh =
        (data?['refreshToken'] ?? data?['refresh_token']) as String?;

    if (newAccess == null || newAccess.isEmpty) {
      // A 200 we can't read is a contract bug, not a dead session. Throwing
      // routes it through onError's non-401 branch, which keeps the tokens.
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Refresh response had no access token',
      );
    }

    await _tokens.saveTokens(
      accessToken: newAccess,
      refreshToken: newRefresh,
    );
    return newAccess;
  }

  Future<void> _failAndLogout() async {
    await _tokens.clear();
    await onAuthFailure();
  }
}
