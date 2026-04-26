import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/leaderboard/data/models/leaderboard_dto.dart';

void main() {
  group('LeaderboardDto', () {
    test('parses the canonical wire shape and ranks by points desc', () {
      final dto = LeaderboardDto.tryParse({
        'projectId': 'p1',
        'lastUpdated': '2026-04-20T08:30:00.000Z',
        'users': [
          {
            '_id': 'u1',
            'username': 'alice',
            'completeName': 'Alice Cooper',
            'points': 30,
            'badges': ['Explorer'],
          },
          {
            '_id': 'u2',
            'username': 'bob',
            'completeName': 'Bob Marley',
            'points': 90,
            'badges': ['Explorer', 'Pioneer'],
          },
          {
            '_id': 'u3',
            'username': 'carol',
            'completeName': 'Carol Danvers',
            'points': 60,
            'badges': <String>[],
          },
        ],
      });

      expect(dto, isNotNull);
      expect(dto!.projectId, 'p1');
      expect(dto.users, hasLength(3));

      final entity = dto.toEntity();
      expect(entity.entries, hasLength(3));
      expect(entity.entries.map((e) => e.username), [
        'bob',
        'carol',
        'alice',
      ]);
      // Ranks are 1-based and computed from sorted order.
      expect(entity.entries[0].rank, 1);
      expect(entity.entries[1].rank, 2);
      expect(entity.entries[2].rank, 3);
      expect(entity.entries[0].points, 90);
      expect(entity.entries[0].badgesCount, 2);
      expect(entity.lastUpdated?.toUtc().year, 2026);
    });

    test('tolerates the {data: ...} envelope', () {
      final dto = LeaderboardDto.tryParse({
        'data': {
          'projectId': 'p2',
          'users': [
            {
              '_id': 'u1',
              'username': 'alice',
              'completeName': 'Alice',
              'points': 5,
              'badges': <String>[],
            },
          ],
        },
      });

      expect(dto, isNotNull);
      expect(dto!.projectId, 'p2');
      expect(dto.users, hasLength(1));
      expect(dto.users.first.username, 'alice');
    });

    test('coerces points coming through as a string', () {
      final dto = LeaderboardDto.tryParse({
        'projectId': 'p3',
        'users': [
          {
            '_id': 'u1',
            'username': 'a',
            'completeName': 'A',
            'points': '42',
            'badges': <String>[],
          },
        ],
      });
      expect(dto, isNotNull);
      expect(dto!.users.first.points, 42);
    });

    test('drops user rows missing both _id and username', () {
      final dto = LeaderboardDto.tryParse({
        'projectId': 'p4',
        'users': [
          {'completeName': 'Ghost'},
          {
            '_id': 'u1',
            'username': 'a',
            'completeName': 'A',
            'points': 1,
            'badges': <String>[],
          },
        ],
      });
      expect(dto, isNotNull);
      expect(dto!.users, hasLength(1));
      expect(dto.users.first.id, 'u1');
    });

    test('returns null on totally garbage payloads', () {
      expect(LeaderboardDto.tryParse(null), isNull);
      expect(LeaderboardDto.tryParse('nope'), isNull);
      expect(LeaderboardDto.tryParse(42), isNull);
    });

    test('toEntity().entryForUser locates the signed-in user', () {
      final entity = LeaderboardDto.tryParse({
        'projectId': 'p5',
        'users': [
          {
            '_id': 'u1',
            'username': 'a',
            'completeName': 'A',
            'points': 10,
            'badges': <String>[],
          },
          {
            '_id': 'u2',
            'username': 'b',
            'completeName': 'B',
            'points': 20,
            'badges': <String>[],
          },
        ],
      })!.toEntity();

      expect(entity.entryForUser('u2')?.rank, 1);
      expect(entity.entryForUser('u1')?.rank, 2);
      expect(entity.entryForUser('nope'), isNull);
    });

    test('falls back to username when completeName is empty', () {
      final entity = LeaderboardDto.tryParse({
        'projectId': 'p6',
        'users': [
          {
            '_id': 'u1',
            'username': 'solo',
            'completeName': '',
            'points': 1,
            'badges': <String>[],
          },
        ],
      })!.toEntity();
      expect(entity.entries.first.displayName, 'solo');
    });
  });
}
