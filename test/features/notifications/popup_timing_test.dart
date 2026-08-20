import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/notifications/data/badge_notification_recorder.dart';
import 'package:rayuela_mobile/features/notifications/data/notifications_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Reproduces the ordering that made the popup show up a visit late.
///
/// The notification is written by the very sync the project screen kicks
/// off, so at the moment the screen first builds there is nothing pending
/// yet. A one-shot check on the first frame therefore always loses. These
/// tests pin the sequence the screen now relies on: nothing → sync →
/// something, with the pending row appearing *after* the first look.
void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase db;
  late NotificationsDao dao;
  late BadgeNotificationRecorder recorder;

  ProjectDetail detail() => ProjectDetail(
        id: 'p1',
        name: 'Río Manzanares',
        description: '',
        available: true,
        badges: [
          ProjectBadge(
            name: 'Explorador',
            status: 'faded',
            expiresAt: DateTime.now().add(const Duration(days: 4)),
          ),
        ],
      );

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = NotificationsDao(db.db);
    recorder = BadgeNotificationRecorder(dao);
  });

  tearDown(() async => db.close());

  test('nothing is pending before the first sync completes', () async {
    expect(await dao.nextUnseen(userId: 'u1', projectId: 'p1'), isNull);
  });

  test('the event turns up only once the sync has run', () async {
    // What the screen sees on its first frame.
    expect(await dao.nextUnseen(userId: 'u1', projectId: 'p1'), isNull);

    // ...and then the fetch lands and the recorder writes.
    await recorder.record(userId: 'u1', detail: detail());

    final pending = await dao.nextUnseen(userId: 'u1', projectId: 'p1');
    expect(pending, isNotNull);
    expect(pending!.subject, 'Explorador');
  });

  test('the badge name survives so the popup can navigate to it', () async {
    await recorder.record(userId: 'u1', detail: detail());
    final pending = await dao.nextUnseen(userId: 'u1', projectId: 'p1');

    // This is what "See badge" hands back to the screen.
    expect(pending!.subject, 'Explorador');
    expect(
      detail().badges.any((b) => b.name == pending.subject),
      isTrue,
      reason: 'the subject must match a badge in the catalog by name',
    );
  });

  test('a notice opened from the centre does not also pop up', () async {
    await recorder.record(userId: 'u1', detail: detail());
    final fromCentre = await dao.nextUnseen(userId: 'u1', projectId: 'p1');

    // Tapping it in the list counts as engaging with it.
    await dao.markSeen(fromCentre!.id);

    expect(await dao.nextUnseen(userId: 'u1', projectId: 'p1'), isNull);
  });
}
