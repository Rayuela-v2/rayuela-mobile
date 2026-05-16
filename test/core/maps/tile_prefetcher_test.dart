import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rayuela_mobile/core/maps/tile_cache_service.dart';
import 'package:rayuela_mobile/core/maps/tile_prefetcher.dart';

/// Test double for [TileCacheService] that records every URL the
/// prefetcher asks for and never hits the network.
class _SpyCache extends TileCacheService {
  _SpyCache() : super(manager: _NoopManager());
  final urls = <String>[];

  @override
  Future<void> prefetchTile(String url) async {
    urls.add(url);
  }

  @override
  Future<Uint8List?> getTileBytes(String url) async => null;
}

/// Stub CacheManager that does nothing — the test never reaches its
/// methods because [_SpyCache] overrides the public API.
class _NoopManager implements CacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('prefetchAreas walks the full zoom range and reports completion',
      () async {
    final cache = _SpyCache();
    final pf = TilePrefetcher(
      cache: cache,
      // Tight zoom band keeps the test fast.
      config: const TilePrefetchConfig(minZoom: 14, maxZoom: 14),
    );

    final progress = <TilePrefetchProgress>[];
    final outcome = await pf.prefetchAreas(
      rings: [
        [const LatLng(-34.605, -58.382), const LatLng(-34.604, -58.381)],
      ],
      onProgress: progress.add,
    );

    expect(outcome, isA<TilePrefetchSucceeded>());
    final succeeded = outcome as TilePrefetchSucceeded;
    expect(succeeded.tiles, cache.urls.length);
    // Final progress event must hit 100 %.
    expect(progress.last.completed, succeeded.tiles);
    expect(progress.last.total, succeeded.tiles);
  });

  test('aborts when the projected tile count exceeds the safety cap',
      () async {
    final cache = _SpyCache();
    final pf = TilePrefetcher(
      cache: cache,
      // 1 tile cap forces the abort branch even for the smallest box.
      config: const TilePrefetchConfig(
        minZoom: 14,
        maxZoom: 17,
        maxTiles: 1,
      ),
    );

    final outcome = await pf.prefetchAreas(
      rings: [
        [
          const LatLng(-34.65, -58.45),
          const LatLng(-34.55, -58.35),
        ],
      ],
    );

    expect(outcome, isA<TilePrefetchTooLarge>());
    expect(cache.urls, isEmpty,
        reason: 'no HTTP work should happen when the cap blocks the run');
  });

  test('reports succeeded(0) for an empty rings list', () async {
    final cache = _SpyCache();
    final pf = TilePrefetcher(cache: cache);

    final outcome = await pf.prefetchAreas(rings: const []);
    expect(outcome, isA<TilePrefetchSucceeded>());
    expect((outcome as TilePrefetchSucceeded).tiles, 0);
    expect(cache.urls, isEmpty);
  });
}
