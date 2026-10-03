import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/app_notification.dart';

/// Renders a stored notification into the current locale.
///
/// Lives apart from the widgets because the same wording feeds three
/// surfaces — the centre's list, the popup, and (next) the scheduled OS
/// notification — and they must not drift into three different phrasings of
/// the same event.
extension AppNotificationCopy on AppNotification {
  String title(AppLocalizations t) => switch (type) {
        AppNotificationType.badgeFading => earned
            ? t.notification_badge_fading_earned_title(subject)
            : t.notification_badge_fading_title(subject),
        AppNotificationType.badgeExpired => earned
            ? t.notification_badge_expired_earned_title(subject)
            : t.notification_badge_expired_title(subject),
      };

  String body(AppLocalizations t) {
    final project = projectName ?? '';
    return switch (type) {
      AppNotificationType.badgeFading => earned
          ? t.notification_badge_fading_earned_body(project)
          : t.notification_badge_fading_body(project),
      AppNotificationType.badgeExpired => earned
          ? t.notification_badge_expired_earned_body(project)
          : t.notification_badge_expired_body(project),
    };
  }

  /// Live countdown, or null when there's nothing left to count.
  ///
  /// A row sits in the centre long after its deadline, so this is computed
  /// against the clock every time it's read — never frozen at write time.
  String? countdown(AppLocalizations t) {
    if (type != AppNotificationType.badgeFading || earned || !windowStillOpen) {
      return null;
    }
    final left = expiresAt!.difference(DateTime.now());
    if (left.inHours >= 24) return t.badge_fading_days(left.inDays);
    if (left.inMinutes >= 60) return t.badge_fading_hours(left.inHours);
    return t.badge_fading_last_call;
  }
}
