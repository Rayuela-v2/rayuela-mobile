import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/theme/app_theme.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/dashboard/presentation/widgets/badge_status_look.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

void main() {
  late AppLocalizations t;
  final theme = ThemeData.light();

  setUpAll(() async {
    t = await AppLocalizations.delegate.load(const Locale('es'));
  });

  ProjectBadge badge({
    String status = 'active',
    DateTime? expiresAt,
    bool earned = false,
  }) =>
      ProjectBadge(
        name: 'B',
        status: status,
        expiresAt: expiresAt,
        earned: earned,
      );

  group('BadgeStatusLook', () {
    test('an ordinary badge is never urgent', () {
      final locked = BadgeStatusLook.of(badge(), theme, t);
      expect(locked.urgent, isFalse);
      expect(locked.label, t.badge_locked);
      expect(locked.compactCountdown, isNull);

      final earned = BadgeStatusLook.of(badge(earned: true), theme, t);
      expect(earned.label, t.badge_earned);
      expect(earned.color, theme.colorScheme.tertiary);
    });

    test('a fading badge shouts, in amber, with the time left', () {
      final look = BadgeStatusLook.of(
        badge(
          status: 'faded',
          expiresAt: DateTime.now().add(const Duration(days: 3, hours: 2)),
        ),
        theme,
        t,
      );
      expect(look.urgent, isTrue);
      expect(look.color, RayuelaColors.warning);
      expect(look.compactCountdown, '3d');
      expect(look.label, contains(t.badge_fading));
      expect(look.label, contains(t.badge_fading_days(3)));
    });

    test('switches to hours inside the last day', () {
      final look = BadgeStatusLook.of(
        badge(
          status: 'faded',
          expiresAt: DateTime.now().add(const Duration(hours: 5, minutes: 1)),
        ),
        theme,
        t,
      );
      expect(look.compactCountdown, '5h');
      expect(look.label, contains(t.badge_fading_hours(5)));
    });

    test('truncates instead of over-promising the time left', () {
      // 3d 23h must read as 3 days, never 4 — the deadline is what it is.
      final look = BadgeStatusLook.of(
        badge(
          status: 'faded',
          expiresAt: DateTime.now().add(const Duration(days: 3, hours: 23)),
        ),
        theme,
        t,
      );
      expect(look.compactCountdown, '3d');
    });

    test('never bottoms out at "0 days left"', () {
      // 23h is less than a day: the unit steps down to hours rather than
      // rounding to a zero that reads as already lost.
      final look = BadgeStatusLook.of(
        badge(
          status: 'faded',
          expiresAt: DateTime.now().add(const Duration(hours: 23)),
        ),
        theme,
        t,
      );
      expect(look.compactCountdown, '22h');
      expect(look.label, isNot(contains('0')));
    });

    test('drops the number entirely in the final hour', () {
      final look = BadgeStatusLook.of(
        badge(
          status: 'faded',
          expiresAt: DateTime.now().add(const Duration(minutes: 20)),
        ),
        theme,
        t,
      );
      expect(look.compactCountdown, '<1h');
      expect(look.label, contains(t.badge_fading_last_call));
    });

    test('an elapsed window reads as gone, not as a countdown', () {
      // The offline cache can hand back a 'faded' payload long after its
      // deadline; the tile must not keep advertising a race that ended.
      final look = BadgeStatusLook.of(
        badge(
          status: 'faded',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        theme,
        t,
      );
      expect(look.urgent, isFalse);
      expect(look.compactCountdown, isNull);
      expect(look.label, t.badge_expired);
    });

    test('an expired badge you already hold still reads as a win', () {
      final mine = BadgeStatusLook.of(
        badge(status: 'expired', earned: true),
        theme,
        t,
      );
      expect(mine.label, t.badge_earned);
      expect(mine.color, theme.colorScheme.tertiary);
      expect(mine.icon, Icons.workspace_premium);

      final missed = BadgeStatusLook.of(badge(status: 'expired'), theme, t);
      expect(missed.label, t.badge_expired);
      expect(missed.icon, Icons.block);
    });
  });
}
