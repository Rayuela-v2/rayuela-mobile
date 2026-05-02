import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_dao.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_entry.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase db;
  late OutboxDao dao;

  OutboxEntry _entry({
    required String id,
    required String userId,
    String projectId = 'p1',
    String? taskId,
    String taskType = 'observation',
    DateTime? createdAt,
    OutboxStatus status = OutboxStatus.pending,
    int attemptCount = 0,
    DateTime? nextAttemptAt,
    List<OutboxImage> images = const [],
  }) {
    final now = createdAt ?? DateTime.utc(2026, 5, 1, 12);
    return OutboxEntry(
      id: id,
      userId: userId,
      projectId: projectId,
      taskId: taskId,
      taskType: taskType,
      latitude: '-34.6',
      longitude: '-58.4',
      datetime: now,
      clientCapturedAt: now,
      images: images,
      status: status,
      attemptCount: attemptCount,
      nextAttemptAt: nextAttemptAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = OutboxDao(db.db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert persists row + image attachments transactionally', () async {
    await dao.insert(
      _entry(
        id: 'a',
        userId: 'u1',
        images: const [
          OutboxImage(
            position: 0,
            filePath: '/tmp/0.jpg',
            byteSize: 10,
            mimeType: 'image/jpeg',
          ),
          OutboxImage(
            position: 1,
            filePath: '/tmp/1.jpg',
            byteSize: 20,
            mimeType: 'image/jpeg',
          ),
        ],
      ),
    );

    final found = await dao.findById('a');
    expect(found, isNotNull);
    expect(found!.images, hasLength(2));
    expect(found.images.first.filePath, '/tmp/0.jpg');
  });

  test('nextEligible returns oldest pending row for the user', () async {
    final t0 = DateTime.utc(2026, 5, 1, 8);
    final t1 = DateTime.utc(2026, 5, 1, 9);
    final t2 = DateTime.utc(2026, 5, 1, 10);

    await dao.insert(_entry(id: 'middle', userId: 'u1', createdAt: t1));
    await dao.insert(_entry(id: 'oldest', userId: 'u1', createdAt: t0));
    await dao.insert(_entry(id: 'newest', userId: 'u1', createdAt: t2));
    // Different user — must not interfere.
    await dao.insert(_entry(id: 'other', userId: 'u2', createdAt: t0));

    final next = await dao.nextEligible('u1');
    expect(next?.id, 'oldest');
  });

  test('nextEligible respects next_attempt_at scheduling', () async {
    final past = DateTime.utc(2026, 5, 1, 8);
    final future = DateTime.utc(2026, 5, 2, 8);

    await dao.insert(_entry(
      id: 'soon',
      userId: 'u1',
      status: OutboxStatus.failed,
      nextAttemptAt: past,
    ));
    await dao.insert(_entry(
      id: 'later',
      userId: 'u1',
      status: OutboxStatus.failed,
      nextAttemptAt: future,
      createdAt: DateTime.utc(2026, 5, 1, 7), // older than `soon`
    ));

    final at = DateTime.utc(2026, 5, 1, 10);
    final next = await dao.nextEligible('u1', now: at);
    expect(next?.id, 'soon',
        reason: '`later`s next_attempt_at is in the future, must be skipped');
  });

  test('markFailed bumps attempt and sets retry schedule', () async {
    await dao.insert(_entry(id: 'r', userId: 'u1'));
    final retryAt = DateTime.utc(2026, 5, 1, 13);
    await dao.markFailed(
      'r',
      attemptCount: 1,
      nextAttemptAt: retryAt,
      errorCode: 'http_503',
      errorMessage: 'Server unavailable',
    );

    final row = await dao.findById('r');
    expect(row!.status, OutboxStatus.failed);
    expect(row.attemptCount, 1);
    expect(row.nextAttemptAt?.toUtc(), retryAt);
    expect(row.lastErrorCode, 'http_503');
  });

  test('markDead clears the retry schedule', () async {
    await dao.insert(_entry(id: 'd', userId: 'u1'));
    await dao.markDead(
      'd',
      attemptCount: 7,
      errorCode: 'validation',
      errorMessage: 'lat invalid',
    );

    final row = await dao.findById('d');
    expect(row!.status, OutboxStatus.dead);
    expect(row.nextAttemptAt, isNull);
  });

  test('reclaimStaleInflight resets long-running inflight rows', () async {
    await dao.insert(_entry(id: 'stuck', userId: 'u1'));
    await dao.markInflight('stuck');
    // Backdate by hand — the DAO doesn't expose updated_at directly.
    await db.db.rawUpdate(
      "UPDATE outbox_checkins SET updated_at = ? WHERE id = ?",
      ['2020-01-01T00:00:00Z', 'stuck'],
    );

    final reclaimed = await dao.reclaimStaleInflight();
    expect(reclaimed, 1);

    final row = await dao.findById('stuck');
    expect(row!.status, OutboxStatus.pending);
  });

  test('pendingCount excludes dead rows', () async {
    await dao.insert(_entry(id: 'a', userId: 'u1'));
    await dao.insert(_entry(
      id: 'b',
      userId: 'u1',
      status: OutboxStatus.failed,
      attemptCount: 2,
    ));
    await dao.insert(_entry(
      id: 'c',
      userId: 'u1',
      status: OutboxStatus.dead,
      attemptCount: 7,
    ));

    expect(await dao.pendingCount('u1'), 2);
  });

  test('knownIds returns the full id set for sweepOrphans', () async {
    await dao.insert(_entry(id: 'one', userId: 'u1'));
    await dao.insert(_entry(id: 'two', userId: 'u2'));
    expect(await dao.knownIds(), {'one', 'two'});
  });

  test('delete removes the row and cascades to images', () async {
    await dao.insert(
      _entry(
        id: 'gone',
        userId: 'u1',
        images: const [
          OutboxImage(
            position: 0,
            filePath: '/tmp/x.jpg',
            byteSize: 1,
            mimeType: 'image/jpeg',
          ),
        ],
      ),
    );
    await dao.delete('gone');

    expect(await dao.findById('gone'), isNull);
    final imgs = await db.db.query(
      'outbox_checkin_images',
      where: 'outbox_id = ?',
      whereArgs: ['gone'],
    );
    expect(imgs, isEmpty);
  });
}
