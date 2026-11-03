import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/maps/cached_tile_provider.dart';
import 'package:rayuela_mobile/core/maps/tile_cache_service.dart';
import 'package:rayuela_mobile/core/network/user_agent_http_overrides.dart';

class _CapturingFileService implements FileService {
  @override
  int concurrentFetches = 10;

  String? lastUrl;
  Map<String, String>? lastHeaders;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    lastUrl = url;
    lastHeaders = headers;
    return _StubFileServiceResponse();
  }
}

class _StubFileServiceResponse implements FileServiceResponse {
  @override
  Stream<List<int>> get content =>
      Stream<List<int>>.value(const <int>[137, 80, 78, 71]);

  @override
  int? get contentLength => 4;

  @override
  String? get eTag => 'etag-1';

  @override
  String get fileExtension => '.png';

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 14));
}

class _HeaderSpyCacheManager implements CacheManager {
  Map<String, String>? lastGetSingleFileHeaders;
  Map<String, String>? lastDownloadFileHeaders;

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async {
    lastDownloadFileHeaders = authHeaders;
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getSingleFile) {
      lastGetSingleFileHeaders =
          invocation.namedArguments[#headers] as Map<String, String>?;
      throw Exception('stop before disk');
    }
    return null;
  }
}

void main() {
  test('TileCacheService.cacheKey uses v2 namespace to drop blocked entries', () {
    expect(TileCacheService.cacheKey, 'rayuela_map_tiles_v2');
  });

  test('UserAgentHttpFileService injects compliant User-Agent on HTTP requests',
      () async {
    final delegate = _CapturingFileService();
    final fileService = UserAgentHttpFileService(delegate: delegate);

    await fileService.get('https://tile.openstreetmap.org/14/5524/9875.png');

    expect(delegate.lastHeaders, isNotNull);
    expect(
      delegate.lastHeaders!['User-Agent'],
      RayuelaUserAgent.defaultValue,
    );
    expect(
      delegate.lastHeaders!['User-Agent'],
      isNot(contains('Dart/')),
    );
  });

  test('UserAgentHttpFileService allows caller headers to override User-Agent',
      () async {
    final delegate = _CapturingFileService();
    final fileService = UserAgentHttpFileService(delegate: delegate);

    await fileService.get(
      'https://tile.openstreetmap.org/14/5524/9875.png',
      headers: const <String, String>{'User-Agent': 'CustomBackendUA/2.0'},
    );

    expect(
      delegate.lastHeaders!['User-Agent'],
      'CustomBackendUA/2.0',
    );
  });

  test('TileCacheService forwards User-Agent headers to CacheManager', () async {
    final spyManager = _HeaderSpyCacheManager();
    final service = TileCacheService(manager: spyManager);

    await service.getTileBytes(
      'https://tile.openstreetmap.org/14/5524/9875.png',
    );
    expect(
      spyManager.lastGetSingleFileHeaders?['User-Agent'],
      RayuelaUserAgent.defaultValue,
    );

    await service.prefetchTile(
      'https://tile.openstreetmap.org/14/5524/9875.png',
    );
    expect(
      spyManager.lastDownloadFileHeaders?['User-Agent'],
      RayuelaUserAgent.defaultValue,
    );
  });

  test('CachedTileProvider defaults to RayuelaUserAgent.defaultValue', () {
    final spyManager = _HeaderSpyCacheManager();
    final provider = CachedTileProvider(
      cache: TileCacheService(manager: spyManager),
    );
    expect(provider.headers['User-Agent'], RayuelaUserAgent.defaultValue);
  });
}
