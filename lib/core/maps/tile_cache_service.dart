import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../network/user_agent_http_overrides.dart';

/// Custom [HttpFileService] that guarantees every outbound HTTP tile
/// download carries a compliant `User-Agent` header (per the OpenStreetMap
/// Tile Usage Policy: https://operations.osmfoundation.org/policies/tiles/)
/// instead of `package:http`'s default `Dart/<version> (dart:io)` string.
class UserAgentHttpFileService extends HttpFileService {
  UserAgentHttpFileService({
    FileService? delegate,
    this.userAgent = RayuelaUserAgent.defaultValue,
  }) : _delegate = delegate;

  final FileService? _delegate;
  final String userAgent;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) {
    final mergedHeaders = <String, String>{
      'User-Agent': userAgent,
      ...?headers,
    };
    final d = _delegate;
    if (d != null) {
      return d.get(url, headers: mergedHeaders);
    }
    return super.get(url, headers: mergedHeaders);
  }
}

/// Single-tenant tile cache used by [CachedTileProvider] and the
/// pre-cache loop in `tile_prefetcher.dart`.
///
/// Sized for OpenStreetMap raster tiles:
///
///   * **maxAgeCacheObject**: 14 days — tiles change rarely; the
///     freshness budget biases towards offline usefulness over
///     bleeding-edge accuracy (exceeds OSM's 7-day minimum).
///   * **maxNrOfCacheObjects**: 4000 — at ~12 KB per PNG ≈ 50 MB cap.
///     Hard ceiling; old tiles get LRU-evicted before new ones land.
///   * **stalePeriod**: matches `maxAgeCacheObject`.
///
/// Production code reads/writes via [getTileBytes] / [prefetchTile] so
/// the underlying [CacheManager] stays an implementation detail.
class TileCacheService {
  TileCacheService({
    CacheManager? manager,
    this.userAgent = RayuelaUserAgent.defaultValue,
  }) : _manager = manager ?? defaultManager;

  final CacheManager _manager;
  final String userAgent;
  CacheManager get manager => _manager;

  /// Default cache key — bumped to `v2` so existing installations drop
  /// any stale or previously blocked (`403`) cache entries and fetch
  /// fresh tiles with a compliant `User-Agent`.
  static const String cacheKey = 'rayuela_map_tiles_v2';

  /// Default singleton used when callers don't inject one. Lazily
  /// constructed so tests can replace it before first use.
  static final CacheManager defaultManager = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 4000,
      repo: JsonCacheInfoRepository(databaseName: cacheKey),
      fileService: UserAgentHttpFileService(),
    ),
  );

  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    return <String, String>{
      'User-Agent': userAgent,
      ...?headers,
    };
  }

  /// Fetch one tile, hitting the cache when possible. Returns the raw
  /// bytes — flutter_map's [TileProvider] decodes them.
  Future<Uint8List?> getTileBytes(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final file = await _manager.getSingleFile(
        url,
        headers: _mergeHeaders(headers),
      );
      return await file.readAsBytes();
    } catch (_) {
      // Network failure with no cached copy: signal to flutter_map
      // that the tile is unavailable (the layer renders a placeholder).
      return null;
    }
  }

  /// Best-effort warm-up: download the URL into the cache without
  /// returning the bytes. Used by the pre-cache loop. Errors are
  /// swallowed so a single failed tile doesn't abort a 1000-tile batch.
  Future<void> prefetchTile(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      await _manager.downloadFile(
        url,
        authHeaders: _mergeHeaders(headers),
      );
    } catch (_) {/* tolerated */}
  }

  /// Wipe the entire OSM tile cache. Surfaced by the "Clear map cache"
  /// action in Settings / Pending data.
  Future<void> clear() async {
    await _manager.emptyCache();
  }
}
