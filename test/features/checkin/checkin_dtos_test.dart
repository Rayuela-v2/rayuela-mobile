import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/checkin/data/models/checkin_dtos.dart';

void main() {
  group('CheckinResultDto', () {
    test('parses the full POST /checkin response shape', () {
      final dto = CheckinResultDto.fromJson({
        'id': 'mv1',
        'checkin': {
          'id': 'ck1',
          'latitude': '40.4',
          'longitude': '-3.7',
          'date': '2025-04-23T10:30:00.000Z',
          'projectId': 'p1',
          'imageRefs': ['checkins/u1/a.jpg', 'checkins/u1/b.jpg'],
          'taskType': 'observation',
          // Backend leaks the User entity here with underscore fields. We
          // ignore it — but it must not break parsing.
          'user': {
            '_id': 'u1',
            '_username': 'fran',
          },
        },
        'gameStatus': {
          'newPoints': 25,
          'newBadges': [
            {'name': 'First check-in', 'description': 'Welcome aboard'},
          ],
          'newLeaderboard': <dynamic>[],
        },
        'score': 5,
        'timestamp': '2025-04-23T10:30:00.000Z',
        'contributesTo': {'id': 't1', 'name': 'Spot a kingfisher'},
      });

      expect(dto.id, 'mv1');
      expect(dto.pointsAwarded, 25);
      expect(dto.imageRefs, hasLength(2));
      expect(dto.imageRefs.first, 'checkins/u1/a.jpg');
      expect(dto.newBadges, hasLength(1));
      expect(dto.newBadges.single.name, 'First check-in');
      expect(dto.score, 5);
      expect(dto.contributesTo!.id, 't1');
      expect(dto.contributesTo!.name, 'Spot a kingfisher');
      expect(
        dto.timestamp.toUtc(),
        DateTime.utc(2025, 4, 23, 10, 30),
      );
    });

    test('handles a stripped-down response (no badges, no contributesTo)', () {
      final dto = CheckinResultDto.fromJson({
        'id': 'mv2',
        'checkin': {'imageRefs': <dynamic>[]},
        'gameStatus': {'newPoints': 0, 'newBadges': <dynamic>[]},
        'timestamp': '2025-04-23T11:00:00.000Z',
      });
      expect(dto.pointsAwarded, 0);
      expect(dto.newBadges, isEmpty);
      expect(dto.contributesTo, isNull);
    });

    test('tolerates string-only badges', () {
      final dto = CheckinResultDto.fromJson({
        'id': 'mv3',
        'checkin': {'imageRefs': <dynamic>[]},
        'gameStatus': {
          'newPoints': 5,
          'newBadges': ['Trailblazer'],
        },
        'timestamp': '2025-04-23T11:00:00.000Z',
      });
      expect(dto.newBadges.single.name, 'Trailblazer');
      expect(dto.newBadges.single.description, isNull);
    });

    test('does not crash when gameStatus is missing', () {
      final dto = CheckinResultDto.fromJson({
        'id': 'mv4',
        'checkin': {'imageRefs': <dynamic>[]},
      });
      expect(dto.pointsAwarded, 0);
      expect(dto.newBadges, isEmpty);
    });

    test('toEntity composes a score message when score is present', () {
      final entity = CheckinResultDto.fromJson({
        'id': 'mv5',
        'checkin': {'imageRefs': <dynamic>[]},
        'gameStatus': {'newPoints': 10, 'newBadges': <dynamic>[]},
        'score': 4,
        'timestamp': '2025-04-23T11:00:00.000Z',
      }).toEntity();
      expect(entity.message, 'Quality score: 4/5');
    });
  });
}
