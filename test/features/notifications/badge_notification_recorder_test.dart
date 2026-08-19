import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/notifications/data/badge_notification_recorder.dart';
import 'package:rayuela_mobile/features/notifications/data/notifications_dao.dart';
import 'package:rayuela_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ProjectDetail project(List<ProjectBadge> badges) => ProjectDetail(
      id: 'p1',
      name: 'Río Manzanares',
      description: '',
      available: true,
      badges: badges,
    );

ProjectBadge fading(String name, {Duration inFuture = const Duration(days: 5)}) =>
    ProjectBadge(
      name: name,
      status: 'faded',
      expiresAt: DateTime.now().add(inFuture),
      fadeReason: 'poca actividad',
    );

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase db;
  late NotificationsDao dao;
  late BadgeNotificationRecorder recorder;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dao = NotificationsDao(db.db);
    recorder = BadgeNotificationRecorder(dao);
  });

  tearDown(() async => db.close());

  group('derivation', () {
    test('ignores a catalog where nothing is happening', () {
      final events = BadgeNotificationRecorder.eventsFor(
        'u1',
        project(const [ProjectBadge(name: 'A'), ProjectBadge(name: 'B')]),
      );
      expect(events, isEmpty);
    });

    test('carries the deadline and the reason onto the event', () {
      final badge = fading('Explorador');
      final event = BadgeNotificationRecorder.eventsFor(
        'u1',
        project([badge]),
      ).single;

      expect(event.type, AppNotificationType.badgeFading);
      expect(event.subject, 'Explorador');
      expect(event.projectName, 'Río Manzanares');
      expect(event.expiresAt, badge.expiresAt);
      expect(event.fadeReason, 'poca actividad');
    });

    test('reads an elapsed window as an expiry, not a countdown', () {
      final events = BadgeNotificationRecorder.eventsFor(
        'u1',
        project([fading('Gone', inFuture: const Duration(days: -1))]),
      );
      expect(events.single.type, AppNotificationType.badgeExpired);
    });
  });

  group('recording', () {
    test('says it once, no matter how often the project is synced', () async {
      final detail = project([fading('Explorador')]);

      expect(await recorder.record(userId: 'u1', detail: detail), 1);
      expect(await recorder.record(userId: 'u1', detail: detail), 0);
      expect(await recorder.record(userId: 'u1', detail: detail), 0);
      expect(await dao.list('u1'), hasLength(1));
    });

    test('speaks up again when the admin moves the deadline', () async {
      await recorder.record(
        userId: 'u1',
        detail: project([fading('Explorador')]),
      );
      final second = await recorder.record(
        userId: 'u1',
        detail: project([fading('Explorador', inFuture: const Duration(days: 9))]),
      );

      // A new window is new information, so it earns a new entry.
      expect(second, 1);
      expect(await dao.list('u1'), hasLength(2));
    });

    test('stays quiet about badges that were already gone on first sync',
        () async {
      // Fresh install against a project with a badge retired months ago:
      // the user never had a shot at it, so "you missed it" is just noise.
      final recorded = await recorder.record(
        userId: 'u1',
        detail: project([
          fading('Ancient', inFuture: const Duration(days: -200)),
        ]),
      );

      expect(recorded, 0);
      expect(await dao.list('u1'), isEmpty);
    });

    test('announces the expiry of a badge it had flagged as fading', () async {
      await recorder.record(
        userId: 'u1',
        detail: project([fading('Explorador')]),
      );

      // Same badge, same window, but the clock has now passed it.
      final recorded = await recorder.record(
        userId: 'u1',
        detail: project([
          fading('Explorador', inFuture: const Duration(days: -1)),
        ]),
      );

      expect(recorded, 1);
      final types = (await dao.list('u1')).map((n) => n.type).toSet();
      expect(types, {
        AppNotificationType.badgeFading,
        AppNotificationType.badgeExpired,
      });
    });

    test('keeps two accounts on one device apart', () async {
      final detail = project([fading('Explorador')]);
      await recorder.record(userId: 'u1', detail: detail);

      expect(await dao.list('u2'), isEmpty);
      expect(await dao.unreadCount('u2'), 0);
      expect(await recorder.record(userId: 'u2', detail: detail), 1);
    });

    test('does nothing at all when nobody is signed in', () async {
      expect(
        await recorder.record(
          userId: '',
          detail: project([fading('Explorador')]),
        ),
        0,
      );
    });
  });

  group('centre state', () {
    test('everything starts unread and clears in one go', () async {
      await recorder.record(
        userId: 'u1',
        detail: project([fading('A'), fading('B')]),
      );
      expect(await dao.unreadCount('u1'), 2);

      await dao.markAllRead('u1');
      expect(await dao.unreadCount('u1'), 0);
      expect((await dao.list('u1')).every((n) => n.isRead), isTrue);
    });

    test('a popup interrupts once and then steps aside', () async {
      await recorder.record(
        userId: 'u1',
        detail: project([fading('A'), fading('B')]),
      );

      final first = await dao.nextUnseen(userId: 'u1', projectId: 'p1');
      expect(first, isNotNull);
      await dao.markSeen(first!.id);

      // The backlog doesn't all pop at once; the next one waits its turn.
      final second = await dao.nextUnseen(userId: 'u1', projectId: 'p1');
      expect(second!.id, isNot(first.id));

      await dao.markSeen(second.id);
      expect(await dao.nextUnseen(userId: 'u1', projectId: 'p1'), isNull);
    });

    test('round-trips the payload through storage', () async {
      final badge = fading('Explorador');
      await recorder.record(userId: 'u1', detail: project([badge]));

      final stored = (await dao.list('u1')).single;
      expect(stored.subject, 'Explorador');
      expect(stored.projectName, 'Río Manzanares');
      expect(stored.fadeReason, 'poca actividad');
      expect(
        stored.expiresAt!.toIso8601String(),
        badge.expiresAt!.toIso8601String(),
      );
      expect(stored.windowStillOpen, isTrue);
    });
  });
}
