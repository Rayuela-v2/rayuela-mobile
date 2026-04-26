import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

/// Adds `Authorization: Bearer <token>` to every request, unless the
/// request is explicitly marked anonymous via `options.extra['anonymous'] = true`.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens);

  final SecureTokenStore _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final anonymous = options.extra['anonymous'] == true;
    if (anonymous) {
      handler.next(options);
      return;
    }
    final token = await _tokens.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
