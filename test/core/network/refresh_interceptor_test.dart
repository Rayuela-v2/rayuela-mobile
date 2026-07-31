import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/network/refresh_interceptor.dart';
import 'package:rayuela_mobile/core/storage/secure_token_store.dart';

/// In-memory stand-in for the keychain.
class _FakeTokenStore extends SecureTokenStore {
  String? access = 'old-access';
  String? refresh = 'user-id.secret';
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    access = accessToken;
    if (refreshToken != null) refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    access = null;
    refresh = null;
  }
}

/// Answers `/auth/refresh` with whatever the test asks for; every other
/// path 401s so the interceptor always kicks in.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.onRefresh);

  final Future<ResponseBody> Function() onRefresh;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/refresh')) return onRefresh();
    return ResponseBody.fromString(
      '{"message":"Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(
  _FakeTokenStore tokens,
  Future<ResponseBody> Function() onRefresh, {
  required void Function() onAuthFailure,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
  dio.httpClientAdapter = _StubAdapter(onRefresh);
  dio.interceptors.add(
    RefreshInterceptor(
      dio: dio,
      tokens: tokens,
      onAuthFailure: onAuthFailure,
    ),
  );
  return dio;
}

void main() {
  test('keeps the session when the refresh call cannot reach the server',
      () async {
    final tokens = _FakeTokenStore();
    var signedOut = false;
    final dio = _dioWith(
      tokens,
      () => throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        reason: 'no route to host',
      ),
      onAuthFailure: () => signedOut = true,
    );

    await expectLater(dio.get<dynamic>('/user'), throwsA(isA<DioException>()));

    // Offline is not a reason to log anybody out.
    expect(tokens.cleared, isFalse);
    expect(tokens.refresh, 'user-id.secret');
    expect(signedOut, isFalse);
  });

  test('keeps the session when the refresh call 500s', () async {
    final tokens = _FakeTokenStore();
    var signedOut = false;
    final dio = _dioWith(
      tokens,
      () async => ResponseBody.fromString('boom', 500),
      onAuthFailure: () => signedOut = true,
    );

    await expectLater(dio.get<dynamic>('/user'), throwsA(isA<DioException>()));

    expect(tokens.cleared, isFalse);
    expect(signedOut, isFalse);
  });

  test('ends the session when the backend rejects the refresh token',
      () async {
    final tokens = _FakeTokenStore();
    var signedOut = false;
    final dio = _dioWith(
      tokens,
      () async => ResponseBody.fromString(
        '{"message":"Invalid refresh token"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      onAuthFailure: () => signedOut = true,
    );

    await expectLater(dio.get<dynamic>('/user'), throwsA(isA<DioException>()));

    expect(tokens.cleared, isTrue);
    expect(signedOut, isTrue);
  });

  test('keeps the session when the refresh returns 200 with an unreadable body',
      () async {
    final tokens = _FakeTokenStore();
    var signedOut = false;
    final dio = _dioWith(
      tokens,
      () async => ResponseBody.fromString(
        '{"unexpected":"shape"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      onAuthFailure: () => signedOut = true,
    );

    await expectLater(dio.get<dynamic>('/user'), throwsA(isA<DioException>()));

    // A contract mismatch must never cost the user their session.
    expect(tokens.cleared, isFalse);
    expect(signedOut, isFalse);
  });

  test('replays the original request with the refreshed access token',
      () async {
    final tokens = _FakeTokenStore();
    var refreshCalls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    dio.httpClientAdapter = _StubAdapter(() async {
      refreshCalls++;
      return ResponseBody.fromString(
        // Exactly what AuthService.refreshAccessToken returns — snake_case.
        jsonEncode({
          'access_token': 'new-access',
          'refresh_token': 'user-id.secret',
          'expires_in': 3600,
          'username': 'testuser',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    // Succeed on the replay only, so we can prove the retry happened.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.extra['_retried'] == true) {
            handler.resolve(
              Response<dynamic>(requestOptions: options, data: {'ok': true}),
            );
            return;
          }
          handler.next(options);
        },
      ),
    );
    dio.interceptors.add(
      RefreshInterceptor(dio: dio, tokens: tokens, onAuthFailure: () {}),
    );

    final res = await dio.get<dynamic>('/user');

    expect(res.data, {'ok': true});
    expect(refreshCalls, 1);
    expect(tokens.access, 'new-access');
    expect(tokens.cleared, isFalse);
  });
}
