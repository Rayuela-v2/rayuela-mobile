import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Slippy-map tile coordinates (Web Mercator, EPSG:3857).
///
/// See https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames for the
/// reference formula. We expose the integer (x, y, z) tuple plus a
/// helper that turns it into an OSM tile URL.
class TileCoord {
  const TileCoord(this.x, this.y, this.z);
  final int x;
  final int y;
  final int z;

  /// Substitute into an `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
  /// style template.
  String urlFrom(String template) {
    return template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Project a single [LatLng] to its containing tile at zoom [z].
TileCoord latLngToTile(LatLng p, int z) {
  final n = 1 << z;
  final lat = p.latitude * math.pi / 180.0;
  final x = ((p.longitude + 180.0) / 360.0 * n).floor();
  final y = ((1 -
              math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) /
          2 *
          n)
      .floor();
  return TileCoord(x.clamp(0, n - 1), y.clamp(0, n - 1), z);
}

/// Bounding box for a list of polygon rings. Returns `null` for empty
/// input — callers should guard against that.
class LatLngBox {
  const LatLngBox(this.south, this.west, this.north, this.east);

  final double south;
  final double west;
  final double north;
  final double east;

  static LatLngBox? around(Iterable<List<LatLng>> rings) {
    double? minLat, maxLat, minLng, maxLng;
    for (final ring in rings) {
      for (final pt in ring) {
        minLat = minLat == null ? pt.latitude : math.min(minLat, pt.latitude);
        maxLat = maxLat == null ? pt.latitude : math.max(maxLat, pt.latitude);
        minLng = minLng == null ? pt.longitude : math.min(minLng, pt.longitude);
        maxLng = maxLng == null ? pt.longitude : math.max(maxLng, pt.longitude);
      }
    }
    if (minLat == null) return null;
    return LatLngBox(minLat, minLng!, maxLat!, maxLng!);
  }
}

/// Enumerate every tile that intersects [box] at zoom [z]. The result
/// list is bounded by the slippy-map grid width `2^z` so very small
/// boxes still return at least one tile.
List<TileCoord> tilesForBox(LatLngBox box, int z) {
  final nw = latLngToTile(LatLng(box.north, box.west), z);
  final se = latLngToTile(LatLng(box.south, box.east), z);
  final out = <TileCoord>[];
  final xStart = math.min(nw.x, se.x);
  final xEnd = math.max(nw.x, se.x);
  final yStart = math.min(nw.y, se.y);
  final yEnd = math.max(nw.y, se.y);
  for (var y = yStart; y <= yEnd; y++) {
    for (var x = xStart; x <= xEnd; x++) {
      out.add(TileCoord(x, y, z));
    }
  }
  return out;
}

/// Total number of tiles that would be enumerated by [tilesForBox] for
/// each zoom in `[minZoom, maxZoom]`. Useful to gate the pre-cache
/// before doing any I/O.
int countTiles({
  required LatLngBox box,
  required int minZoom,
  required int maxZoom,
}) {
  var total = 0;
  for (var z = minZoom; z <= maxZoom; z++) {
    total += tilesForBox(box, z).length;
  }
  return total;
}
