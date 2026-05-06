import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'tile_cache_service.dart';

/// flutter_map [TileProvider] that pulls bytes from [TileCacheService]
/// instead of going straight to the network.
///
/// When a tile is missing from the cache the service issues an HTTP
/// fetch and stores the response; subsequent renders (and offline
/// reloads) come straight from disk.
///
/// `userAgentPackageName` is forwarded as the OSM-mandated `User-Agent`
/// per https://operations.osmfoundation.org/policies/tiles/.
class CachedTileProvider extends TileProvider {
  CachedTileProvider({
    required this.cache,
    String? userAgentPackageName,
    Map<String, String>? headers,
  }) : super(
          headers: <String, String>{
            'User-Agent':
                userAgentPackageName ?? 'rayuela_mobile/1.0 (offline)',
            ...?headers,
          },
        );

  final TileCacheService cache;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(
      url: getTileUrl(coordinates, options),
      cache: cache,
    );
  }
}

/// Custom [ImageProvider] that delegates byte loading to the
/// [TileCacheService] singleton. Mostly mirrors flutter_map's own
/// `NetworkTileImage`, swapping out the byte source.
class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({required this.url, required this.cache});

  final String url;
  final TileCacheService cache;

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachedTileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await cache.getTileBytes(url);
    if (bytes == null) {
      throw NetworkImageLoadException(statusCode: 0, uri: Uri.parse(url));
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
