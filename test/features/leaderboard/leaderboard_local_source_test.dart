import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:rayuela_mobile/features/leaderboard/data/sources/leaderboard_local_source.dart';
import 'package:rayuela_mobile/features/leaderboard/domain/entities/leaderboard.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase db;
  late LeaderboardLocalSource local;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    local = LeaderboardLocalSource(db.db);
  });

  tearDown(() async => db.close());

  test('round-trips a leaderboard with rank ordering', () async {
    final at = DateTime.utc(2026, 5, 5, 11);
    final lb = Leaderboard(
      projectId: 'p1',
      lastUpdated: at,
      entries: const [
        LeaderboardEntry(
          rank: 1,
          userId: 'u1',
          username: 'fran',
          completeName: 'Fran Pérez',
          points: 200,
          badges: ['Pioneer'],
        ),
        LeaderboardEntry(
          rank: 2,
          userId: 'u2',
          username: 'pep',
          completeName: '',
          points: 150,
          badges: [],
        ),
      ],
    );

    await local.write(
      userId: 'u1',
      projectId: 'p1',
      leaderboard: lb,
      fetchedAt: at,
    );

    final cached = await local.read(userId: 'u1', projectId: 'p1');
    expect(cached, isNotNull);
    expect(cached!.value.entries, hasLength(2));
    expect(cached.value.entries.first.rank, 1);
    expect(cached.value.entries.first.points, 200);
    expect(cached.value.lastUpdated, at);
  });

  test('clearForUser removes that user\'s rows only', () async {
    final at = DateTime.utc(2026, 5, 5);
    await local.write(
      userId: 'u1',
      projectId: 'p1',
      leaderboard: const Leaderboard(projectId: 'p1', entries: []),
      fetchedAt: at,
    );
    await local.write(
      userId: 'u2',
      projectId: 'p1',
      leaderboard: const Leaderboard(projectId: 'p1', entries: []),
      fetchedAt: at,
    );

    await local.clearForUser('u1');
    expect(await local.read(userId: 'u1', projectId: 'p1'), isNull);
    expect(await local.read(userId: 'u2', projectId: 'p1'), isNotNull);
  });
}
