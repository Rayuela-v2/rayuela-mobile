import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/auth/data/models/auth_dtos.dart';
import 'package:rayuela_mobile/features/profile/data/sources/profile_stats_remote_source.dart';
import 'package:rayuela_mobile/features/profile/domain/entities/profile_avatar.dart';

void main() {
  group('ProfileAvatar.resolve', () {
    test('resolves a stored catalog pick', () {
      final first = ProfileAvatar.catalog.first;
      expect(ProfileAvatar.resolve(first.storageValue), same(first));
    });

    test('returns null for URLs, empties and unknown ids', () {
      expect(ProfileAvatar.resolve(null), isNull);
      expect(ProfileAvatar.resolve(''), isNull);
      expect(ProfileAvatar.resolve('https://lh3.google.com/pic.jpg'), isNull);
      // An id added by a newer app version must degrade, not crash.
      expect(ProfileAvatar.resolve('avatar:astronaut'), isNull);
    });

    test('catalog ids are unique', () {
      final ids = ProfileAvatar.catalog.map((a) => a.id).toSet();
      expect(ids, hasLength(ProfileAvatar.catalog.length));
    });
  });

  group('profile wire shapes', () {
    test('UpdateProfileRequestDto omits untouched fields', () {
      expect(
        const UpdateProfileRequestDto(description: 'hola').toJson(),
        {'description': 'hola'},
      );
      expect(const UpdateProfileRequestDto().toJson(), isEmpty);
    });

    test('UserDto reads description from both wire shapes', () {
      expect(
        UserDto.fromJson({'_username': 'fran', '_description': 'bio'})
            .description,
        'bio',
      );
      expect(
        UserDto.fromJson({'username': 'fran', 'description': 'bio'})
            .toEntity()
            .description,
        'bio',
      );
      // Missing on the wire (pre-migration users) must not blow up.
      expect(UserDto.fromJson({'username': 'fran'}).description, '');
    });

    test('UserDto parses createdAt for "exploring since"', () {
      final user = UserDto.fromJson({
        'username': 'fran',
        '_createdAt': '2026-01-05T12:00:00.000Z',
      }).toEntity();
      expect(user.createdAt?.year, 2026);
      expect(user.createdAt?.month, 1);
      // A garbage date degrades to null instead of throwing.
      expect(
        UserDto.fromJson({'username': 'fran', 'createdAt': 'nope'})
            .toEntity()
            .createdAt,
        isNull,
      );
    });
  });

  group('parseProfileStats', () {
    test('reads totals and folds byProject into a map', () {
      final stats = parseProfileStats({
        'total': 7,
        'streakDays': 2,
        'activeDays': 3,
        'byProject': [
          {'projectId': 'p1', 'count': 4},
          {'projectId': 'p2', 'count': 3},
        ],
      });
      expect(stats.totalCheckins, 7);
      expect(stats.streakDays, 2);
      expect(stats.activeDays, 3);
      expect(stats.checkinsFor('p1'), 4);
      expect(stats.checkinsFor('nope'), 0);
    });

    test('survives a missing or malformed payload', () {
      expect(parseProfileStats(null).totalCheckins, 0);
      expect(parseProfileStats('boom').totalCheckins, 0);
      final partial = parseProfileStats({
        'total': '5',
        'byProject': [
          {'count': 1}, // no projectId — skipped
          'garbage',
        ],
      });
      expect(partial.totalCheckins, 5);
      expect(partial.checkinsByProject, isEmpty);
      expect(partial.streakDays, 0);
    });
  });
}
