import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/error/app_exception.dart';
import 'package:rayuela_mobile/core/error/result.dart';
import 'package:rayuela_mobile/core/network/api_client.dart';
import 'package:rayuela_mobile/core/storage/secure_token_store.dart';

class _FakeSecureStorage extends Mock implements FlutterSecureStorage {}

/// Smoke test: given a stubbed Dio, the ApiClient translates each Dio
/// error type into the correct [AppException] subclass.
void main() {
  late _StubAdapter adapter;
  late Dio dio;
  late ApiClient client;

  setUp(() {
    final storage = _FakeSecureStorage();
    // Auth interceptor asks for the token; returning null means the request
    // is sent without an Authorization header — fine for these tests.
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);

    adapter = _StubAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    client = ApiClient(
      tokens: SecureTokenStore(storage),
      onAuthFailure: () async {},
      dio: dio,
    );
  });

  test('400 with NestJS message array → ValidationException', () async {
    adapter.response = ResponseBody.fromString(
      '{"message":["email must be an email"],"statusCode":400}',
      400,
      headers: const {
        'content-type': ['application/json'],
      },
    );

    final result = await client.request<String>(
      (d) => d.get<Map<String, dynamic>>('/any'),
      parse: (_) => 'ok',
    );

    expect(result, isA<Failure<String>>());
    final error = (result as Failure<String>).error;
    expect(error, isA<ValidationException>());
    expect(
      (error as ValidationException).fieldErrors.containsKey('email'),
      isTrue,
    );
  });

  test('401 → UnauthorizedException', () async {
    adapter.response = ResponseBody.fromString(
      '{"message":"Invalid credentials","statusCode":401}',
      401,
      headers: const {
        'content-type': ['application/json'],
      },
    );

    final result = await client.request<String>(
      (d) => d.get<Map<String, dynamic>>('/any'),
      parse: (_) => 'ok',
    );

    expect((result as Failure<String>).error, isA<UnauthorizedException>());
  });

  test('5xx → ServerException with status code', () async {
    adapter.response = ResponseBody.fromString(
      '{"message":"boom","statusCode":500}',
      500,
      headers: const {
        'content-type': ['application/json'],
      },
    );

    final result = await client.request<String>(
      (d) => d.get<Map<String, dynamic>>('/any'),
      parse: (_) => 'ok',
    );

    final error = (result as Failure<String>).error;
    expect(error, isA<ServerException>());
    expect((error as ServerException).statusCode, 500);
  });
}

/// Minimal Dio adapter that always returns the same configured body.
class _StubAdapter implements HttpClientAdapter {
  ResponseBody? response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final r = response;
    if (r == null) throw StateError('Stub response not set');
    return r;
  }

  @override
  void close({bool force = false}) {}
}
