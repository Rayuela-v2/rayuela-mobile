import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/secure_token_store.dart';
import 'api_paths.dart';

/// On a 401, tries to refresh the access token once and replay the original
/// request. Gated by [Env.useRefreshToken] because the backend ships the
/// refresh endpoint in §4.1 of the migration plan.
///
/// If refresh fails, the store is cleared and the caller sees the 401 —
/// the auth controller listens for this and navigates to /login.
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

    if (!Env.useRefreshToken || !is401 || alreadyRetried || isRefreshCall) {
      handler.next(err);
      return;
    }

    try {
      final newAccess = await (_inFlightRefresh ??= _refresh());
      _inFlightRefresh = null;

      if (newAccess == null) {
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
      await _failAndLogout();
      handler.next(e);
    } catch (_) {
      _inFlightRefresh = null;
      await _failAndLogout();
      handler.next(err);
    }
  }

  Future<String?> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;

    final response = await _dio.post<Map<String, dynamic>>(
      ApiPaths.refresh,
      data: {'refreshToken': refresh},
      options: Options(extra: {'anonymous': true}),
    );

    final data = response.data;
    if (data == null) return null;
    final newAccess = data['accessToken'] as String?;
    final newRefresh = data['refreshToken'] as String?;
    if (newAccess == null) return null;
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
