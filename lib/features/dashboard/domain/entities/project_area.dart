import 'package:latlong2/latlong.dart';

/// One polygon "area" within a project. Backend stores areas as a GeoJSON
/// FeatureCollection on `project.areas`; each Feature has:
///   - `geometry.type` = `"Polygon"` | `"MultiPolygon"`
///   - `geometry.coordinates` in `[lon, lat]` order
///   - `properties.id` = the human-readable area name (used as the link key
///     against `task.areaGeoJSON.properties.id`)
///
/// We hold the outer ring(s) as `latlong2.LatLng` so flutter_map can render
/// them directly. Holes are dropped — no project uses them today, and Polygon
/// support in flutter_map is per-ring.
class ProjectArea {
  const ProjectArea({
    required this.id,
    required this.rings,
  });

  /// Both display name and join key — backend keeps these the same.
  final String id;

  /// One ring per polygon; each ring is a closed loop of `LatLng`. A simple
  /// Polygon contributes one ring; a MultiPolygon contributes one per piece.
  final List<List<LatLng>> rings;

  String get name => id;

  /// Centroid across all rings, used to anchor markers and as a fallback
  /// camera target when no other points are available. Cheap arithmetic
  /// mean — good enough for fitting the camera.
  LatLng? get centroid {
    final pts = <LatLng>[];
    for (final r in rings) {
      pts.addAll(r);
    }
    if (pts.isEmpty) return null;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }
}
