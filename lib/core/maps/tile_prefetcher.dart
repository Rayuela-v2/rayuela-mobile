import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'tile_cache_service.dart';
import 'tile_math.dart';

/// Sane defaults aligned with `docs/OFFLINE_SYNC_PLAN.md` §5.5: ~30 MB
/// per project at zoom 16-18. Anything beyond that pushes into "you
/// downloaded the entire neighbourhood" territory and starts costing
/// real data.
class TilePrefetchConfig {
  const TilePrefetchConfig({
    this.minZoom = 14,
    this.maxZoom = 17,
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.maxTiles = 2500,
    this.parallelism = 4,
  });

  final int minZoom;
  final int maxZoom;
  final String urlTemplate;

  /// Hard ceiling before the pre-cache aborts. Protects against a
  /// volunteer accidentally downloading a whole country (e.g. an area
  /// drawn around a bad GPS reading).
  final int maxTiles;

  /// How many concurrent HTTP requests to fire. The OSM tile policy
  /// asks for "no bulk downloads"; 4 is well within polite limits and
  /// matches what most maps clients use.
  final int parallelism;
}

/// One-tick progress emitted while a project is being pre-cached.
class TilePrefetchProgress {
  const TilePrefetchProgress({
    required this.completed,
    required this.total,
    this.failed = 0,
  });

  final int completed;
  final int total;
  final int failed;

  double get fraction => total == 0 ? 1.0 : completed / total;
  bool get isDone => completed + failed >= total;
}

/// Result the [TilePrefetcher] returns when an entire project finishes
/// (or is cancelled / aborted at the safety ceiling).
sealed class TilePrefetchOutcome {
  const TilePrefetchOutcome();
}

class TilePrefetchSucceeded extends TilePrefetchOutcome {
  const TilePrefetchSucceeded({required this.tiles});
  final int tiles;
}

class TilePrefetchTooLarge extends TilePrefetchOutcome {
  const TilePrefetchTooLarge({required this.estimated, required this.cap});
  final int estimated;
  final int cap;
}

class TilePrefetchCancelled extends TilePrefetchOutcome {
  const TilePrefetchCancelled();
}

/// Walks the slippy-map grid for a project's areas and warms the tile
/// cache. Runs entirely off [TileCacheService.prefetchTile], so any
/// failed tile is logged-and-skipped rather than aborting the batch.
///
/// Use:
///   final ctrl = StreamController<TilePrefetchProgress>();
///   final outcome = await prefetcher.prefetchAreas(
///     rings: project.areas.expand((a) => a.rings),
///     onProgress: ctrl.add,
///   );
class TilePrefetcher {
  TilePrefetcher({
    required TileCacheService cache,
    TilePrefetchConfig config = const TilePrefetchConfig(),
  })  : _cache = cache,
        _config = config;

  final TileCacheService _cache;
  final TilePrefetchConfig _config;

  bool _cancelled = false;

  /// Sets the cancel flag so the next batch boundary aborts the loop.
  /// Safe to call from a button tap.
  void cancel() {
    _cancelled = true;
  }

  Future<TilePrefetchOutcome> prefetchAreas({
    required Iterable<List<LatLng>> rings,
    void Function(TilePrefetchProgress)? onProgress,
  }) async {
    final box = LatLngBox.around(rings);
    if (box == null) {
      return const TilePrefetchSucceeded(tiles: 0);
    }

    final estimated = countTiles(
      box: box,
      minZoom: _config.minZoom,
      maxZoom: _config.maxZoom,
    );
    if (estimated > _config.maxTiles) {
      return TilePrefetchTooLarge(
        estimated: estimated,
        cap: _config.maxTiles,
      );
    }

    final coords = <TileCoord>[];
    for (var z = _config.minZoom; z <= _config.maxZoom; z++) {
      coords.addAll(tilesForBox(box, z));
    }

    var completed = 0;
    var failed = 0;
    final total = coords.length;
    onProgress?.call(TilePrefetchProgress(completed: 0, total: total));

    // Bounded parallelism: chunk the coordinate list into groups of
    // [parallelism] and await each group sequentially. Keeps the total
    // outstanding HTTP requests predictable.
    for (var i = 0; i < coords.length; i += _config.parallelism) {
      if (_cancelled) {
        return const TilePrefetchCancelled();
      }
      final batch = coords.sublist(
        i,
        (i + _config.parallelism).clamp(0, coords.length),
      );
      await Future.wait(
        batch.map((c) async {
          final url = c.urlFrom(_config.urlTemplate);
          try {
            await _cache.prefetchTile(url);
            completed++;
          } catch (_) {
            failed++;
          }
        }),
      );
      onProgress?.call(
        TilePrefetchProgress(
          completed: completed,
          total: total,
          failed: failed,
        ),
      );
    }

    return TilePrefetchSucceeded(tiles: completed);
  }
}
