import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Single-tenant tile cache used by [CachedTileProvider] and the
/// pre-cache loop in `tile_prefetcher.dart`.
///
/// Sized for OpenStreetMap raster tiles:
///
///   * **maxAgeCacheObject**: 14 days — tiles change rarely; the
///     freshness budget biases towards offline usefulness over
///     bleeding-edge accuracy.
///   * **maxNrOfCacheObjects**: 4000 — at ~12 KB per PNG ≈ 50 MB cap.
///     Hard ceiling; old tiles get LRU-evicted before new ones land.
///   * **stalePeriod**: matches `maxAgeCacheObject`.
///
/// Production code reads/writes via [getTileBytes] / [prefetchTile] so
/// the underlying [CacheManager] stays an implementation detail.
class TileCacheService {
  TileCacheService({CacheManager? manager})
      : _manager = manager ?? defaultManager;

  final CacheManager _manager;
  CacheManager get manager => _manager;

  /// Default cache key — flutter_cache_manager namespaces files by it.
  static const String cacheKey = 'rayuela_osm_tiles';

  /// Default singleton used when callers don't inject one. Lazily
  /// constructed so tests can replace it before first use.
  static final CacheManager defaultManager = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 4000,
      repo: JsonCacheInfoRepository(databaseName: cacheKey),
      fileService: HttpFileService(),
    ),
  );

  /// Fetch one tile, hitting the cache when possible. Returns the raw
  /// bytes — flutter_map's [TileProvider] decodes them.
  Future<Uint8List?> getTileBytes(String url) async {
    try {
      final file = await _manager.getSingleFile(url);
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
  Future<void> prefetchTile(String url) async {
    try {
      await _manager.downloadFile(url);
    } catch (_) {/* tolerated */}
  }

  /// Wipe the entire OSM tile cache. Surfaced by the "Clear map cache"
  /// action in Settings / Pending data.
  Future<void> clear() async {
    await _manager.emptyCache();
  }
}
