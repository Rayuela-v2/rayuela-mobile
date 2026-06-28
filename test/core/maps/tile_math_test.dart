import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rayuela_mobile/core/maps/tile_math.dart';

void main() {
  group('latLngToTile', () {
    test('null island lands on (0,0,0) at zoom 0', () {
      expect(latLngToTile(const LatLng(0, 0), 0), const TileCoord(0, 0, 0));
    });

    test('matches the slippy-map reference for Buenos Aires @ z14', () {
      // Reference values cross-checked against
      // https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
      // for (-34.6037, -58.3816, z=14).
      final t = latLngToTile(const LatLng(-34.6037, -58.3816), 14);
      expect(t.x, 5534);
      expect(t.y, 9872);
      expect(t.z, 14);
    });

    test('clamps to the grid bounds at extreme zooms', () {
      final t = latLngToTile(const LatLng(-89.9, 179.9), 5);
      // Must stay inside [0, 31].
      expect(t.x, inInclusiveRange(0, 31));
      expect(t.y, inInclusiveRange(0, 31));
    });
  });

  group('LatLngBox.around', () {
    test('returns null for empty input', () {
      expect(LatLngBox.around(const []), isNull);
    });

    test('computes the convex bbox of multiple rings', () {
      final box = LatLngBox.around([
        [const LatLng(-34.6, -58.4), const LatLng(-34.65, -58.45)],
        [const LatLng(-34.55, -58.35)],
      ]);
      expect(box, isNotNull);
      expect(box!.south, closeTo(-34.65, 1e-9));
      expect(box.north, closeTo(-34.55, 1e-9));
      expect(box.west, closeTo(-58.45, 1e-9));
      expect(box.east, closeTo(-58.35, 1e-9));
    });
  });

  group('tilesForBox / countTiles', () {
    test('a tiny box at low zoom covers exactly one tile', () {
      const box = LatLngBox(-34.61, -58.41, -34.6, -58.4);
      final tiles = tilesForBox(box, 10);
      expect(tiles, hasLength(1));
    });

    test('zoom range counts add up across zooms', () {
      const box = LatLngBox(-34.65, -58.45, -34.55, -58.35);
      final z14 = tilesForBox(box, 14).length;
      final z15 = tilesForBox(box, 15).length;
      final z16 = tilesForBox(box, 16).length;
      final total = countTiles(box: box, minZoom: 14, maxZoom: 16);
      expect(total, z14 + z15 + z16);
    });
  });

  group('TileCoord.urlFrom', () {
    test('substitutes z, x, y in a slippy-map template', () {
      const c = TileCoord(123, 456, 12);
      expect(
        c.urlFrom('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        'https://tile.openstreetmap.org/12/123/456.png',
      );
    });
  });
}
