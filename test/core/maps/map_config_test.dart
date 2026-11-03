import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/maps/map_config.dart';
import 'package:rayuela_mobile/core/network/api_client.dart';
import 'package:rayuela_mobile/core/network/user_agent_http_overrides.dart';
import 'package:rayuela_mobile/core/storage/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTokenStore extends SecureTokenStore {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MapConfig', () {
    test('defaultOsm returns compliant OSM configuration', () {
      final config = MapConfig.defaultOsm();
      expect(
        config.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(config.attributionText, '© OpenStreetMap contributors');
      expect(config.attributionUrl, 'https://www.openstreetmap.org/copyright');
      expect(config.fixMapUrl, 'https://www.openstreetmap.org/fixthemap');
      expect(config.userAgent, RayuelaUserAgent.defaultValue);
      expect(config.cacheMaxAgeDays, 14);
      expect(config.allowBulkPrefetch, isFalse);
    });

    test('fromJson parses custom fields and enforces minimum 7-day cache TTL', () {
      final config = MapConfig.fromJson(const <String, dynamic>{
        'urlTemplate': 'https://tiles.example.com/{z}/{x}/{y}.png',
        'subdomains': <String>['a', 'b'],
        'attributionText': '© Example Maps',
        'attributionUrl': 'https://example.com/copyright',
        'fixMapUrl': 'https://example.com/fix',
        'minZoom': 4,
        'maxZoom': 18,
        'userAgent': 'CustomAgent/1.0',
        'cacheMaxAgeDays': 3,
        'allowBulkPrefetch': true,
      });

      expect(config.urlTemplate, 'https://tiles.example.com/{z}/{x}/{y}.png');
      expect(config.subdomains, <String>['a', 'b']);
      expect(config.attributionText, '© Example Maps');
      expect(config.minZoom, 4);
      expect(config.maxZoom, 18);
      expect(config.userAgent, 'CustomAgent/1.0');
      expect(config.cacheMaxAgeDays, 7);
      expect(config.allowBulkPrefetch, isTrue);
    });
  });

  group('MapConfigController', () {
    test('fetches GET /maps/config and persists to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/v1'));
      dio.httpClientAdapter = _StubAdapter((options) async {
        expect(options.path, '/maps/config');
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'urlTemplate': 'https://custom.tiles.org/{z}/{x}/{y}.png',
            'subdomains': <String>[],
            'attributionText': '© Custom',
            'attributionUrl': 'https://custom.tiles.org/about',
            'fixMapUrl': 'https://custom.tiles.org/fix',
            'minZoom': 2,
            'maxZoom': 19,
            'userAgent': 'RayuelaCustom/1.0',
            'cacheMaxAgeDays': 21,
            'allowBulkPrefetch': true,
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });

      final apiClient = ApiClient(
        tokens: _FakeTokenStore(),
        onAuthFailure: () {},
        dio: dio,
      );

      final controller = MapConfigController(
        prefs: prefs,
        apiClient: apiClient,
        autoRefresh: false,
      );

      final updated = await controller.refresh();
      expect(updated.urlTemplate, 'https://custom.tiles.org/{z}/{x}/{y}.png');
      expect(updated.allowBulkPrefetch, isTrue);
      expect(prefs.getString(kMapConfigPrefsKey), isNotNull);

      // Subsequent offline controller loads cached value immediately
      final offlineController = MapConfigController(
        prefs: prefs,
        autoRefresh: false,
      );
      expect(
        offlineController.state.urlTemplate,
        'https://custom.tiles.org/{z}/{x}/{y}.png',
      );
      expect(offlineController.state.allowBulkPrefetch, isTrue);
    });

    test('falls back to cached or defaultOsm when network fails', () async {
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/v1'));
      dio.httpClientAdapter = _StubAdapter((options) async {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Offline',
        );
      });

      final apiClient = ApiClient(
        tokens: _FakeTokenStore(),
        onAuthFailure: () {},
        dio: dio,
      );

      final controller = MapConfigController(
        prefs: prefs,
        apiClient: apiClient,
        autoRefresh: false,
      );

      final state = await controller.refresh();
      expect(state, MapConfig.defaultOsm());
    });
  });
}
