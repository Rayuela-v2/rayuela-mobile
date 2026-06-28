import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:rayuela_mobile/features/dashboard/data/sources/projects_local_source.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_area.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_summary.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase db;
  late ProjectsLocalSource local;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    local = ProjectsLocalSource(db.db);
  });

  tearDown(() async {
    await db.close();
  });

  group('subscribed list', () {
    test('write then read round-trips a list of summaries', () async {
      final fetchedAt = DateTime.utc(2026, 5, 1, 12);
      await local.writeSubscribed(
        userId: 'u1',
        projects: const [
          ProjectSummary(
            id: 'p1',
            name: 'Plaza',
            description: 'desc',
            available: true,
            isSubscribed: true,
            userPoints: 42,
            userBadgesCount: 3,
          ),
        ],
        fetchedAt: fetchedAt,
      );

      final cached = await local.readSubscribed('u1');
      expect(cached, isNotNull);
      expect(cached!.fetchedAt.toUtc(), fetchedAt);
      expect(cached.value, hasLength(1));
      final p = cached.value.first;
      expect(p.id, 'p1');
      expect(p.name, 'Plaza');
      expect(p.userPoints, 42);
      expect(p.isSubscribed, isTrue);
    });

    test('returns null for users with no cached list', () async {
      expect(await local.readSubscribed('nobody'), isNull);
    });
  });

  group('detail', () {
    test('round-trips a project detail with areas + badges + user stats',
        () async {
      const detail = ProjectDetail(
        id: 'p1',
        name: 'Plaza',
        description: 'd',
        available: true,
        gamificationStrategy: 'BASIC',
        recommendationStrategy: 'SIMPLE',
        leaderboardStrategy: 'POINTS_FIRST',
        badges: const [
          ProjectBadge(
            name: 'Pioneer',
            description: 'first 10',
            earned: true,
            previousBadges: ['Newbie'],
          ),
        ],
        taskTypes: const [
          TaskType(name: 'observation'),
          TaskType(name: 'cleanup'),
        ],
        areas: [
          ProjectArea(
            id: 'North',
            rings: [
              [LatLng(-34.6, -58.4), LatLng(-34.61, -58.4)],
            ],
          ),
        ],
        user: const ProjectUserStats(
          isSubscribed: true,
          points: 100,
          badgesEarned: 2,
          leaderboardRank: 5,
        ),
      );

      await local.writeDetail(
        userId: 'u1',
        projectId: 'p1',
        detail: detail,
        fetchedAt: DateTime.utc(2026, 5, 1, 12),
      );

      final cached = await local.readDetail(userId: 'u1', projectId: 'p1');
      expect(cached, isNotNull);
      final d = cached!.value;
      expect(d.id, 'p1');
      expect(d.areas, hasLength(1));
      expect(d.areas.first.rings.first, hasLength(2));
      expect(d.badges.first.earned, isTrue);
      expect(d.user!.points, 100);
    });
  });
}
