import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/dashboard/data/models/project_detail_dto.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';

void main() {
  group('ProjectDetailDto', () {
    test('parses a subscribed user payload with stitched user.badges', () {
      final dto = ProjectDetailDto.fromJson({
        '_id': 'p1',
        'name': 'River watchers',
        'description': 'Survey the Manzanares.',
        'image': 'https://cdn/p.png',
        'web': 'https://example.com/p1',
        'available': true,
        'gamificationStrategy': 'ELASTIC',
        'recommendationStrategy': 'ADAPTIVE',
        'leaderboardStrategy': 'POINTS_FIRST',
        'taskTypes': ['observation', 'photo'],
        'gamification': {
          'strategy': 'ELASTIC',
          'badgesRules': [
            // The catalog. Each entry will ALSO appear under user.badges
            // when the user is subscribed, with `active` flipped per user.
            {'name': 'First check-in', 'description': 'Welcome aboard'},
            {'name': 'Trailblazer', 'description': '10 in a month'},
          ],
        },
        'user': {
          'isSubscribed': true,
          'points': 42,
          'badges': [
            {'name': 'First check-in', 'active': true},
            {'name': 'Trailblazer', 'active': false},
          ],
          'leaderboard': {'position': 3},
        },
      });

      expect(dto.id, 'p1');
      expect(dto.name, 'River watchers');
      expect(dto.gamificationStrategy, 'ELASTIC');
      expect(dto.recommendationStrategy, 'ADAPTIVE');
      expect(dto.leaderboardStrategy, 'POINTS_FIRST');
      expect(dto.taskTypes, const [
        TaskType(name: 'observation'),
        TaskType(name: 'photo'),
      ]);

      // We pulled badges from the user-stitched list (so .earned is set).
      expect(dto.badges, hasLength(2));
      expect(dto.badges.first.name, 'First check-in');
      expect(dto.badges.first.earned, isTrue);
      expect(dto.badges[1].earned, isFalse);

      expect(dto.user, isNotNull);
      expect(dto.user!.isSubscribed, isTrue);
      expect(dto.user!.points, 42);
      expect(dto.user!.badgesEarned, 1);
      expect(dto.user!.leaderboardRank, 3);
    });

    test('parses an unsubscribed user payload (no `user` block)', () {
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'River watchers',
        'description': 'Survey the Manzanares.',
        'gamification': {
          'strategy': 'BASIC',
          'badgesRules': [
            {'name': 'First check-in'},
          ],
        },
      });

      expect(dto.user, isNull);
      // Falls back to the gamification.badgesRules catalog.
      expect(dto.badges, hasLength(1));
      expect(dto.badges.single.name, 'First check-in');
      expect(dto.badges.single.earned, isFalse);
      expect(dto.gamificationStrategy, 'BASIC');
      // `available` defaults to true when omitted on detail responses.
      expect(dto.available, isTrue);
    });

    test('toEntity surfaces isSubscribed via user overlay', () {
      final entity = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'description': '',
        'user': {'isSubscribed': true, 'points': 0, 'badges': <dynamic>[]},
      }).toEntity();
      expect(entity.isSubscribed, isTrue);
      expect(entity.user!.points, 0);
      expect(entity.user!.badgesEarned, 0);
    });

    test('carries the fading window and per-user satisfied through the merge',
        () {
      final expiresAt = DateTime.utc(2030, 3, 1, 12);
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'gamification': {
          'badgesRules': [
            {
              'name': 'Fading one',
              'status': 'faded',
              'expiresAt': expiresAt.toIso8601String(),
              'fadeReason': 'poca actividad',
            },
            {'name': 'Gone', 'status': 'expired'},
            {'name': 'Normal'},
          ],
        },
        'user': {
          'isSubscribed': true,
          'points': 0,
          'badges': [
            {'name': 'Fading one', 'active': false, 'satisfied': true},
            {'name': 'Gone', 'active': true, 'satisfied': true},
            {'name': 'Normal', 'active': false, 'satisfied': false},
          ],
        },
      });

      final fading = dto.badges.firstWhere((b) => b.name == 'Fading one');
      expect(fading.status, 'faded');
      expect(fading.expiresAt, expiresAt);
      expect(fading.fadeReason, 'poca actividad');
      // Only present on the overlay — reading it off the catalog pinned it false.
      expect(fading.satisfied, isTrue);

      final gone = dto.badges.firstWhere((b) => b.name == 'Gone');
      expect(gone.status, 'expired');
      expect(gone.expiresAt, isNull);
      // An expired badge you already earned stays earned.
      expect(gone.earned, isTrue);

      final normal = dto.badges.firstWhere((b) => b.name == 'Normal');
      expect(normal.status, 'active');
      expect(normal.satisfied, isFalse);
    });

    test('ignores an unparseable expiresAt instead of throwing', () {
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'gamification': {
          'badgesRules': [
            {'name': 'A', 'status': 'faded', 'expiresAt': 'mañana'},
          ],
        },
      });
      expect(dto.badges.single.status, 'faded');
      expect(dto.badges.single.expiresAt, isNull);
    });

    test('closes a window that elapsed while the payload sat in cache', () {
      // The backend said 'faded' when this was fetched; the window has since
      // run out and the device has been offline, so nothing refreshed it.
      const stale = ProjectBadge(name: 'A', status: 'faded');
      final elapsed = ProjectBadge(
        name: 'A',
        status: 'faded',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final live = ProjectBadge(
        name: 'A',
        status: 'faded',
        expiresAt: DateTime.now().add(const Duration(days: 2)),
      );

      expect(elapsed.availability, BadgeAvailability.expired);
      expect(elapsed.timeUntilExpiry, isNull);

      expect(live.availability, BadgeAvailability.fading);
      // 47, not 48: the clock advances between building it and reading it.
      expect(live.timeUntilExpiry!.inHours, 47);

      // No window at all: trust the server's word, don't invent an expiry.
      expect(stale.availability, BadgeAvailability.fading);

      expect(
        const ProjectBadge(name: 'A', status: 'expired').availability,
        BadgeAvailability.expired,
      );
      expect(
        const ProjectBadge(name: 'A').availability,
        BadgeAvailability.active,
      );
      // Corrupt status reads as active, same fallback as the backend.
      expect(
        const ProjectBadge(name: 'A', status: 'pizza').availability,
        BadgeAvailability.active,
      );
    });

    test('handles a string-only badge in the catalog', () {
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'gamification': {
          'badgesRules': ['Trailblazer'],
        },
      });
      expect(dto.badges.single.name, 'Trailblazer');
      expect(dto.badges.single.earned, isFalse);
    });

    test('coerces `active: 1/0` numeric flags on user badges', () {
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'user': {
          'isSubscribed': true,
          'points': 0,
          'badges': [
            {'name': 'A', 'active': 1},
            {'name': 'B', 'active': 0},
          ],
        },
      });
      expect(dto.user!.badgesEarned, 1);
      expect(dto.badges.first.earned, isTrue);
      expect(dto.badges[1].earned, isFalse);
    });

    test('does not crash on garbage payload', () {
      final dto = ProjectDetailDto.fromJson('garbage');
      expect(dto.id, '');
      expect(dto.name, '');
      expect(dto.user, isNull);
      expect(dto.badges, isEmpty);
    });

    test('reads gamificationStrategy from nested gamification.strategy', () {
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'gamification': {'strategy': 'BASIC'},
      });
      expect(dto.gamificationStrategy, 'BASIC');
    });

    test('reads badge image from `imageUrl` (backend canonical field)', () {
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'gamification': {
          'badgesRules': [
            // Canonical name on the backend BadgeRule entity.
            {'name': 'Trailblazer', 'imageUrl': 'https://cdn/t.png'},
            // Legacy spelling — still supported.
            {'name': 'Pioneer', 'image': 'https://cdn/p.png'},
          ],
        },
      });
      expect(dto.badges.first.image, 'https://cdn/t.png');
      expect(dto.badges[1].image, 'https://cdn/p.png');
    });

    test('parses task types given as objects', () {
      final dto = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'taskTypes': [
          {'name': 'Observation', 'description': '...'},
          {'name': 'Photo report'},
          {'description': 'no name — dropped'},
        ],
      });
      expect(dto.taskTypes, const [
        TaskType(name: 'Observation', description: '...'),
        TaskType(name: 'Photo report'),
      ]);
    });

    test('flows project areas through to the entity', () {
      // End-to-end: areas live on `project.areas` as a GeoJSON
      // FeatureCollection. The DTO parses it; toEntity() forwards a
      // ready-to-render list of ProjectArea.
      final entity = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'areas': {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'id': 'Riverside'},
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [-3.70, 40.41],
                    [-3.71, 40.41],
                    [-3.71, 40.42],
                    [-3.70, 40.41],
                  ],
                ],
              },
            },
          ],
        },
      }).toEntity();
      expect(entity.areas, hasLength(1));
      expect(entity.areas.single.id, 'Riverside');
      expect(entity.areas.single.rings, hasLength(1));
      expect(entity.areas.single.centroid, isNotNull);
    });

    test('omitting areas leaves the entity with an empty list', () {
      final entity = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
      }).toEntity();
      expect(entity.areas, isEmpty);
    });

    test('carries the badge earning rule through, treating "Cualquiera" as any',
        () {
      final entity = ProjectDetailDto.fromJson({
        'id': 'p1',
        'name': 'X',
        'gamification': {
          'badgesRules': [
            {
              'name': 'Riverkeeper',
              'checkinsAmount': 3,
              'mustContribute': true,
              'taskType': 'photo',
              'areaId': 'Riverside',
              'timeIntervalId': 'Cualquiera', // "any" → not a constraint
            },
          ],
        },
      }).toEntity();

      final badge = entity.badges.single;
      expect(badge.checkinsAmount, 3);
      expect(badge.mustContribute, isTrue);
      expect(badge.hasTaskType, isTrue);
      expect(badge.taskType, 'photo');
      expect(badge.hasArea, isTrue);
      expect(badge.areaId, 'Riverside');
      // 'Cualquiera' means no restriction on that dimension.
      expect(badge.hasTimeInterval, isFalse);
    });
  });
}
