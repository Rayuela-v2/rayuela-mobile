import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/project_detail.dart';

/// How one badge should read at a glance: colour, icon and wording.
///
/// The grid tile, the detail sheet and the dependency graph all need to agree
/// on what "fading" looks like — three call sites drifting apart is how you
/// end up with an orange ring nobody can decode. This is the one place that
/// decides, so changing the fading colour changes it everywhere.
///
/// Colour is never the only signal: every state also carries an icon and a
/// label, because amber-vs-red rings alone are unreadable for a good chunk of
/// people and mean nothing to anyone without a legend.
@immutable
class BadgeStatusLook {
  const BadgeStatusLook({
    required this.color,
    required this.icon,
    required this.label,
    required this.urgent,
    this.compactCountdown,
  });

  final Color color;
  final IconData icon;

  /// Full wording for a pill or a tooltip, e.g. "¡Se desvanece! · Quedan 3 días".
  final String label;

  /// True while the badge is fading — the state the UI is allowed to shout
  /// about. Drives the glow on tiles and the emphasis in the sheet.
  final bool urgent;

  /// Two-or-three character countdown for tight spots like a grid corner
  /// ("3d", "5h"). Null unless the badge is fading with a known deadline.
  final String? compactCountdown;

  /// Foreground for a chip filled with [color]. Derived from the actual
  /// background because [color] swings between tertiary, amber and grey —
  /// no single `onX` from the scheme contrasts with all three.
  Color get onColor =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black87;

  factory BadgeStatusLook.of(
    ProjectBadge badge,
    ThemeData theme,
    AppLocalizations t,
  ) {
    final scheme = theme.colorScheme;

    switch (badge.availability) {
      case BadgeAvailability.fading:
        final left = badge.timeUntilExpiry;
        return BadgeStatusLook(
          color: RayuelaColors.warning,
          icon: Icons.hourglass_bottom,
          label: '${t.badge_fading} · ${_countdown(left, t)}',
          urgent: true,
          compactCountdown: _compactCountdown(left),
        );

      case BadgeAvailability.expired:
        return BadgeStatusLook(
          // Earning it before the window closed is a win, so an expired badge
          // you actually hold still reads as a trophy, not a tombstone.
          color: badge.earned ? scheme.tertiary : scheme.outline,
          icon: badge.earned ? Icons.workspace_premium : Icons.block,
          label: badge.earned ? t.badge_earned : t.badge_expired,
          urgent: false,
        );

      case BadgeAvailability.active:
        return BadgeStatusLook(
          color: badge.earned ? scheme.tertiary : scheme.outline,
          icon: badge.earned ? Icons.check_circle : Icons.flag_outlined,
          label: badge.earned ? t.badge_earned : t.badge_locked,
          urgent: false,
        );
    }
  }

  /// Spelled-out time left.
  ///
  /// Truncates rather than rounds up — never promise more time than there
  /// actually is, or someone plans for a day that isn't there. It can't
  /// bottom out at a demoralising "0 days left" either, because the unit
  /// steps down before it gets there: days while a full day remains, then
  /// hours, then a plain "last call".
  static String _countdown(Duration? left, AppLocalizations t) {
    if (left == null) return t.badge_fading_call_to_action;
    if (left.inHours >= 24) return t.badge_fading_days(left.inDays);
    if (left.inMinutes >= 60) return t.badge_fading_hours(left.inHours);
    return t.badge_fading_last_call;
  }

  /// 'd' and 'h' happen to be the right initial in all three locales we ship
  /// (días/dias/days, horas/hours), so this stays out of the .arb files. Add a
  /// key here the moment a locale lands where that stops being true.
  static String? _compactCountdown(Duration? left) {
    if (left == null) return null;
    if (left.inHours >= 24) return '${left.inDays}d';
    if (left.inMinutes >= 60) return '${left.inHours}h';
    return '<1h';
  }
}

/// The compact status marker: state icon, plus the countdown when there is
/// one ("⏳ 3d").
///
/// Small enough to hang off a grid tile's corner or float over a graph node,
/// which is exactly the point — the time left has to be legible at a glance.
/// A tooltip doesn't count: on a phone it needs a long-press nobody performs.
class BadgeStatusChip extends StatelessWidget {
  const BadgeStatusChip({
    super.key,
    required this.look,
    this.iconOverride,
  });

  final BadgeStatusLook look;
  final IconData? iconOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countdown = look.compactCountdown;

    return Container(
      padding: countdown == null
          ? const EdgeInsets.all(2)
          : const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: look.color,
        borderRadius: BorderRadius.circular(999),
        // Outlined in the surface colour so the chip stays separated from
        // whatever artwork it overlaps.
        border: Border.all(color: theme.colorScheme.surface, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconOverride ?? look.icon, size: 12, color: look.onColor),
          if (countdown != null) ...[
            const SizedBox(width: 3),
            Text(
              countdown,
              style: theme.textTheme.labelSmall?.copyWith(
                color: look.onColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
