import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/network/api_client.dart';
import 'package:rayuela_mobile/core/network/user_agent_http_overrides.dart';
import 'package:rayuela_mobile/core/storage/secure_token_store.dart';

class _FakeTokenStore extends SecureTokenStore {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;
}

void main() {
  tearDown(() {
    HttpOverrides.global = null;
  });

  group('RayuelaHttpOverrides', () {
    test('sets RayuelaUserAgent.defaultValue on created HttpClient instances', () {
      RayuelaHttpOverrides.install();

      final client = HttpClient();
      expect(client.userAgent, RayuelaUserAgent.defaultValue);
      expect(client.userAgent, isNot(contains('Dart/')));
      client.close(force: true);
    });

    test('supports custom userAgent string when installed', () {
      RayuelaHttpOverrides.install(userAgent: 'CustomRayuela/2.0');

      final client = HttpClient();
      expect(client.userAgent, 'CustomRayuela/2.0');
      client.close(force: true);
    });
  });

  group('ApiClient default User-Agent header', () {
    test('includes User-Agent header in Dio BaseOptions', () {
      final apiClient = ApiClient(
        tokens: _FakeTokenStore(),
        onAuthFailure: () {},
      );

      expect(
        apiClient.raw.options.headers[HttpHeaders.userAgentHeader],
        RayuelaUserAgent.defaultValue,
      );
    });
  });
}
