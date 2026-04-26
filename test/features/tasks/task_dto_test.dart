import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/tasks/data/models/task_dto.dart';

void main() {
  group('TaskDto', () {
    test('parses a clean GET /task/project/:id row', () {
      final dto = TaskDto.fromJson({
        'id': 't1',
        'name': 'Spot a kingfisher',
        'description': 'Look near the riverbank around dawn.',
        'projectId': 'p1',
        'type': 'observation',
        'points': 25,
        'solved': false,
        'timeInterval': {
          'name': 'Spring mornings',
          'days': [1, 2, 3, 4, 5],
          'time': {'start': '06:00', 'end': '10:00'},
          'startDate': '2025-04-01',
          'endDate': '2025-06-30',
        },
      });
      expect(dto.id, 't1');
      expect(dto.name, 'Spot a kingfisher');
      expect(dto.points, 25);
      expect(dto.solved, isFalse);
      expect(dto.timeInterval, isNotNull);
      expect(dto.timeInterval!.days, [1, 2, 3, 4, 5]);
      expect(dto.timeInterval!.startTime, '06:00');
    });

    test('falls back to defaults on a sparse row', () {
      final dto = TaskDto.fromJson({'id': 't1'});
      expect(dto.points, 0);
      expect(dto.solved, isFalse);
      expect(dto.type, '');
      expect(dto.timeInterval, isNull);
    });

    test('returns empty id when payload is not a map', () {
      final dto = TaskDto.fromJson('garbage');
      expect(dto.id, '');
    });

    test('toEntity maps solvedBy through', () {
      final entity = TaskDto.fromJson({
        'id': 't1',
        'name': 'Done',
        'solved': true,
        'solvedBy': 'fran',
        'points': 10,
      }).toEntity();
      expect(entity.solved, isTrue);
      expect(entity.solvedBy, 'fran');
    });

    test('extracts areaName from areaGeoJSON.properties.id', () {
      // Backend canonical wire shape — `areaGeoJSON` is the join key
      // against project.areas[].properties.id.
      final dto = TaskDto.fromJson({
        'id': 't1',
        'name': 'A',
        'areaGeoJSON': {
          'type': 'Feature',
          'geometry': {'type': 'Polygon', 'coordinates': <List<dynamic>>[]},
          'properties': {'id': 'River bank'},
        },
      });
      expect(dto.areaName, 'River bank');
      expect(dto.toEntity().areaName, 'River bank');
    });

    test('falls back to inline areaName / area fields', () {
      // Older admin tooling: a flat `areaName` string in the row.
      expect(
        TaskDto.fromJson({'id': 't1', 'name': 'A', 'areaName': 'Forest'})
            .areaName,
        'Forest',
      );
      expect(
        TaskDto.fromJson({'id': 't1', 'name': 'A', 'area': 'Lake'}).areaName,
        'Lake',
      );
    });

    test('returns null areaName when no area info is present', () {
      final dto = TaskDto.fromJson({'id': 't1', 'name': 'A'});
      expect(dto.areaName, isNull);
    });

    test('returns null areaName when areaGeoJSON has no properties.id', () {
      final dto = TaskDto.fromJson({
        'id': 't1',
        'name': 'A',
        'areaGeoJSON': {
          'type': 'Feature',
          'geometry': {'type': 'Polygon', 'coordinates': <List<dynamic>>[]},
          'properties': <String, dynamic>{}, // no id
        },
      });
      expect(dto.areaName, isNull);
    });
  });
}
