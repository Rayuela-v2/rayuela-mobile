import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/dashboard/data/models/project_detail_dto.dart';

void main() {
  group('ProjectAreaDto.parseFeatureCollection', () {
    test('parses a canonical FeatureCollection with one Polygon', () {
      // GeoJSON convention: [lon, lat]. We project to LatLng (lat, lon).
      final areas = ProjectAreaDto.parseFeatureCollection({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'id': 'River bank'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [-3.70, 40.41],
                  [-3.71, 40.41],
                  [-3.71, 40.42],
                  [-3.70, 40.42],
                  [-3.70, 40.41],
                ],
              ],
            },
          },
        ],
      });

      expect(areas, hasLength(1));
      expect(areas.first.id, 'River bank');
      expect(areas.first.rings, hasLength(1));
      expect(areas.first.rings.first, hasLength(5));
      // [lon, lat] → LatLng(lat, lon).
      expect(areas.first.rings.first.first.latitude, closeTo(40.41, 1e-9));
      expect(areas.first.rings.first.first.longitude, closeTo(-3.70, 1e-9));
    });

    test('handles a MultiPolygon: one ring per piece', () {
      final areas = ProjectAreaDto.parseFeatureCollection({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'id': 'Two islands'},
            'geometry': {
              'type': 'MultiPolygon',
              'coordinates': [
                // Polygon 1
                [
                  [
                    [0.0, 0.0],
                    [1.0, 0.0],
                    [1.0, 1.0],
                    [0.0, 0.0],
                  ],
                ],
                // Polygon 2
                [
                  [
                    [10.0, 10.0],
                    [11.0, 10.0],
                    [11.0, 11.0],
                    [10.0, 10.0],
                  ],
                ],
              ],
            },
          },
        ],
      });

      expect(areas, hasLength(1));
      expect(areas.first.rings, hasLength(2));
    });

    test('drops Polygon holes (only the outer ring is kept)', () {
      final areas = ProjectAreaDto.parseFeatureCollection({
        'features': [
          {
            'type': 'Feature',
            'properties': {'id': 'Donut'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                // Outer
                [
                  [0.0, 0.0],
                  [4.0, 0.0],
                  [4.0, 4.0],
                  [0.0, 4.0],
                  [0.0, 0.0],
                ],
                // Hole — should be dropped
                [
                  [1.0, 1.0],
                  [3.0, 1.0],
                  [3.0, 3.0],
                  [1.0, 3.0],
                  [1.0, 1.0],
                ],
              ],
            },
          },
        ],
      });
      expect(areas.single.rings, hasLength(1));
      expect(areas.single.rings.first, hasLength(5));
    });

    test('tolerates a bare List<Feature> (no FeatureCollection wrapper)', () {
      final areas = ProjectAreaDto.parseFeatureCollection([
        {
          'type': 'Feature',
          'properties': {'id': 'A'},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [0.0, 0.0],
                [1.0, 0.0],
                [1.0, 1.0],
                [0.0, 0.0],
              ],
            ],
          },
        },
      ]);
      expect(areas, hasLength(1));
      expect(areas.single.id, 'A');
    });

    test('drops features missing properties.id', () {
      final areas = ProjectAreaDto.parseFeatureCollection({
        'features': [
          {
            'type': 'Feature',
            'properties': <String, dynamic>{}, // no id
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [0.0, 0.0],
                  [1.0, 0.0],
                  [1.0, 1.0],
                  [0.0, 0.0],
                ],
              ],
            },
          },
          {
            'type': 'Feature',
            'properties': {'id': 'Kept'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [0.0, 0.0],
                  [1.0, 0.0],
                  [1.0, 1.0],
                  [0.0, 0.0],
                ],
              ],
            },
          },
        ],
      });
      expect(areas.map((a) => a.id), ['Kept']);
    });

    test('drops unsupported geometry types (Point/LineString)', () {
      final areas = ProjectAreaDto.parseFeatureCollection({
        'features': [
          {
            'type': 'Feature',
            'properties': {'id': 'Pin'},
            'geometry': {'type': 'Point', 'coordinates': [0.0, 0.0]},
          },
          {
            'type': 'Feature',
            'properties': {'id': 'Trail'},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [0.0, 0.0],
                [1.0, 1.0],
              ],
            },
          },
        ],
      });
      expect(areas, isEmpty);
    });

    test('drops features whose geometry has empty/scalar-noise coordinates', () {
      final areas = ProjectAreaDto.parseFeatureCollection({
        'features': [
          {
            'type': 'Feature',
            'properties': {'id': 'Empty'},
            'geometry': {'type': 'Polygon', 'coordinates': <List<dynamic>>[]},
          },
        ],
      });
      expect(areas, isEmpty);
    });

    test('coerces coordinate strings to doubles', () {
      final areas = ProjectAreaDto.parseFeatureCollection({
        'features': [
          {
            'type': 'Feature',
            'properties': {'id': 'Stringy'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  ['-3.70', '40.41'],
                  ['-3.71', '40.41'],
                  ['-3.71', '40.42'],
                  ['-3.70', '40.41'],
                ],
              ],
            },
          },
        ],
      });
      expect(areas, hasLength(1));
      expect(areas.single.rings.single.first.latitude, closeTo(40.41, 1e-9));
    });

    test('returns an empty list on garbage payloads', () {
      expect(ProjectAreaDto.parseFeatureCollection(null), isEmpty);
      expect(ProjectAreaDto.parseFeatureCollection('nope'), isEmpty);
      expect(ProjectAreaDto.parseFeatureCollection(42), isEmpty);
    });

    test('toEntity preserves id and rings', () {
      final dto = ProjectAreaDto.parseFeatureCollection({
        'features': [
          {
            'type': 'Feature',
            'properties': {'id': 'Round trip'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [0.0, 0.0],
                  [1.0, 0.0],
                  [1.0, 1.0],
                  [0.0, 0.0],
                ],
              ],
            },
          },
        ],
      }).single;
      final entity = dto.toEntity();
      expect(entity.id, 'Round trip');
      expect(entity.name, 'Round trip'); // alias getter
      expect(entity.rings, hasLength(1));
      expect(entity.centroid, isNotNull);
    });
  });
}
