import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/notifications/data/badge_reminder_scheduler.dart';

/// Covers the planning rules only. Whether the OS actually rings is the
/// platform's job and needs a real device — what's testable here is *which*
/// reminders get booked and when, which is where the bugs would live.
void main() {
  final now = DateTime.utc(2026, 6, 1, 12);

  ProjectDetail project(List<ProjectBadge> badges) => ProjectDetail(
        id: 'p1',
        name: 'Río Manzanares',
        description: '',
        available: true,
        badges: badges,
      );

  ProjectBadge fading(
    String name, {
    required Duration inFuture,
    bool earned = false,
  }) =>
      ProjectBadge(
        name: name,
        status: 'faded',
        expiresAt: now.add(inFuture),
        earned: earned,
      );

  List<BadgeReminder> plan(List<ProjectBadge> badges) =>
      BadgeReminderScheduler.remindersFor(project(badges), at: now);

  test('books a heads-up and a final call for a comfortable window', () {
    final reminders = plan([fading('Explorador', inFuture: const Duration(days: 10))]);

    expect(reminders, hasLength(2));
    final heads = reminders.firstWhere((r) => !r.isFinalCall);
    final last = reminders.firstWhere((r) => r.isFinalCall);

    expect(heads.fireAt, now.add(const Duration(days: 7)));
    expect(last.fireAt, now.add(const Duration(days: 10)));
  });

  test('skips the heads-up when the window is shorter than it', () {
    // Two days left: a "3 days to go" reminder would have to fire yesterday.
    final reminders = plan([fading('Explorador', inFuture: const Duration(days: 2))]);

    expect(reminders, hasLength(1));
    expect(reminders.single.isFinalCall, isTrue);
  });

  test('books nothing for a window that already closed', () {
    expect(plan([fading('Gone', inFuture: const Duration(days: -1))]), isEmpty);
  });

  test('leaves alone a badge the user already earned', () {
    // They have it. Counting down at them is nagging about nothing.
    final reminders = plan([
      fading('Mine', inFuture: const Duration(days: 10), earned: true),
    ]);
    expect(reminders, isEmpty);
  });

  test('ignores ordinary badges entirely', () {
    expect(
      plan(const [ProjectBadge(name: 'A'), ProjectBadge(name: 'B')]),
      isEmpty,
    );
  });

  test('carries what the notification text needs', () {
    final r = plan([fading('Explorador', inFuture: const Duration(days: 10))]).first;
    expect(r.badgeName, 'Explorador');
    expect(r.projectName, 'Río Manzanares');
    expect(r.projectId, 'p1');
  });

  group('notification ids', () {
    test('are stable across runs so a reminder can be cancelled later', () {
      // Re-derived, never stored: a rebooked window has to overwrite the
      // reminder booked by an earlier app version, or the user gets both.
      expect(
        BadgeReminder.idFor('p1', 'Explorador', true),
        BadgeReminder.idFor('p1', 'Explorador', true),
      );
    });

    test('separate the heads-up from the final call', () {
      expect(
        BadgeReminder.idFor('p1', 'Explorador', true),
        isNot(BadgeReminder.idFor('p1', 'Explorador', false)),
      );
    });

    test('separate badges and projects', () {
      final ids = {
        BadgeReminder.idFor('p1', 'A', true),
        BadgeReminder.idFor('p1', 'B', true),
        BadgeReminder.idFor('p2', 'A', true),
      };
      expect(ids, hasLength(3));
    });

    test('always fit in a positive 32-bit int', () {
      // The platform channel takes an int32; a negative or oversized id is
      // rejected at the boundary rather than in Dart.
      for (final name in const ['A', 'Explorador', 'ñandú 🦩', '']) {
        final id = BadgeReminder.idFor('project-id-abc123', name, true);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });
}
