import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/checkin/data/models/checkin_history_dto.dart';

void main() {
  group('CheckinHistoryItemDto', () {
    test('parses the canonical CheckInTemplate shape', () {
      final dto = CheckinHistoryItemDto.tryParse({
        '_id': 'c1',
        'projectId': 'p1',
        'taskType': 'Observation',
        'datetime': '2026-04-20T08:30:00.000Z',
        'latitude': '40.4168',
        'longitude': '-3.7038',
        'imageRefs': ['checkins/abc.jpg', 'checkins/def.jpg'],
        'contributesTo': {'id': 't1', 'name': 'River north'},
      });
      expect(dto, isNotNull);
      expect(dto!.id, 'c1');
      expect(dto.taskType, 'Observation');
      expect(dto.datetime.toUtc().year, 2026);
      expect(dto.imageRefs, hasLength(2));
      expect(dto.imageRefs.first, 'checkins/abc.jpg');
      expect(dto.latitude, '40.4168');
      expect(dto.longitude, '-3.7038');
      expect(dto.contributesToId, 't1');
      expect(dto.contributesToName, 'River north');
    });

    test('tolerates a string `contributesTo` (just the task id)', () {
      final dto = CheckinHistoryItemDto.tryParse({
        'id': 'c2',
        'projectId': 'p1',
        'taskType': 'Photo',
        'datetime': 1000000000000,
        'imageRefs': <dynamic>[],
        'contributesTo': 't9',
      });
      expect(dto, isNotNull);
      expect(dto!.contributesToId, 't9');
      expect(dto.contributesToName, isNull);
    });

    test('falls back to `date` and `_imageRefs` aliases', () {
      final dto = CheckinHistoryItemDto.tryParse({
        'id': 'c3',
        'projectId': 'p1',
        'taskType': '',
        'date': '2026-01-02T03:04:05.000Z',
        '_imageRefs': ['k.png'],
      });
      expect(dto, isNotNull);
      expect(dto!.imageRefs, ['k.png']);
      expect(dto.datetime.toUtc().year, 2026);
    });

    test('drops malformed entries (no id)', () {
      final dto = CheckinHistoryItemDto.tryParse({
        'projectId': 'p1',
        'taskType': 'X',
      });
      expect(dto, isNull);
    });

    test('returns null for non-map payload', () {
      expect(CheckinHistoryItemDto.tryParse('garbage'), isNull);
      expect(CheckinHistoryItemDto.tryParse(null), isNull);
    });

    test('toEntity preserves fields and sets convenience flags', () {
      final entity = CheckinHistoryItemDto.tryParse({
        '_id': 'c4',
        'projectId': 'p1',
        'taskType': 'Observation',
        'datetime': '2026-04-20T08:30:00.000Z',
        'latitude': '40.4',
        'longitude': '-3.7',
        'imageRefs': ['a.jpg'],
        'contributesTo': {'id': 't1', 'name': 'River'},
      })!.toEntity();
      expect(entity.hasLocation, isTrue);
      expect(entity.solvesATask, isTrue);
      expect(entity.contributesToTaskName, 'River');
    });
  });
}
