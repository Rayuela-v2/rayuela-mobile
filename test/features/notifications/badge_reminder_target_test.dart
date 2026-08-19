import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/notifications/data/badge_reminder_scheduler.dart';

/// The payload is the only thing that survives between booking a reminder
/// and the user tapping it days later — possibly on a newer build of the
/// app. It has to round-trip, and it has to fail soft.
void main() {
  final fireAt = DateTime.utc(2026, 6, 10);

  test('round-trips through the payload a tap hands back', () {
    final reminder = BadgeReminder(
      projectId: 'p1',
      projectName: 'Río Manzanares',
      badgeName: 'Explorador',
      fireAt: fireAt,
      isFinalCall: true,
    );

    final target = BadgeReminderTarget.tryParse(reminder.payload)!;
    expect(target.projectId, 'p1');
    expect(target.badgeName, 'Explorador');
  });

  test('survives badge names full of separators and emoji', () {
    // Badge names are typed by project admins. Any delimiter we picked would
    // eventually show up inside one, which is why the payload is JSON.
    for (final name in const ['a|b', 'a,b;c', '{"b":"x"}', 'ñandú 🦩', '']) {
      final reminder = BadgeReminder(
        projectId: 'p1',
        projectName: 'P',
        badgeName: name,
        fireAt: fireAt,
        isFinalCall: false,
      );
      expect(
        BadgeReminderTarget.tryParse(reminder.payload)!.badgeName,
        name,
        reason: 'badge name "$name" must survive the round trip',
      );
    }
  });

  test('opens nothing rather than crashing on junk', () {
    // A payload written by another version of the app must not take down the
    // cold-launch path.
    for (final junk in const [
      null,
      '',
      'not json',
      '[]',
      '{}',
      '{"p":""}',
      '{"b":"orphan"}',
    ]) {
      expect(BadgeReminderTarget.tryParse(junk), isNull, reason: 'junk: $junk');
    }
  });

  test('tolerates a payload with no badge, landing on the project', () {
    expect(
      BadgeReminderTarget.tryParse('{"p":"p1"}')!.badgeName,
      '',
    );
  });
}
