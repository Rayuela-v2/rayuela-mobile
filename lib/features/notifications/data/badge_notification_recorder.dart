import '../../dashboard/domain/entities/project_detail.dart';
import '../domain/entities/app_notification.dart';
import 'notifications_dao.dart';

/// Turns a freshly-synced project into notification-centre entries.
///
/// The whole point of Phase A: the backend ships `expiresAt`, so the app can
/// work out on its own that a badge started fading or that its window shut.
/// No `/notifications` endpoint, no push, no server-side event log — just a
/// read of data that already arrives with every project detail.
///
/// The trade-off, stated plainly: notifications only appear once a sync has
/// run. Someone who never opens the app gets nothing here (the scheduled OS
/// notification is what covers that gap). That's the same bargain the rest of
/// this offline-first app already makes.
class BadgeNotificationRecorder {
  const BadgeNotificationRecorder(this._dao);

  final NotificationsDao _dao;

  /// Records anything newsworthy in [detail]. Returns the number of genuinely
  /// new entries, so a caller can skip work when nothing changed.
  Future<int> record({
    required String userId,
    required ProjectDetail detail,
  }) async {
    if (userId.isEmpty) return 0;

    final candidates = eventsFor(userId, detail);
    if (candidates.isEmpty) return 0;

    // "It expired" is only news to someone we told it was fading. On a fresh
    // install every long-dead badge in the catalog would otherwise land in
    // the centre as a missed chance the user never actually had.
    final announcedFading = await _dao.subjectsWithType(
      userId: userId,
      projectId: detail.id,
      type: AppNotificationType.badgeFading,
    );
    final worthSaying = candidates
        .where(
          (e) =>
              e.type != AppNotificationType.badgeExpired ||
              announcedFading.contains(e.subject),
        )
        .toList(growable: false);

    return _dao.recordAll(userId, worthSaying);
  }

  /// Candidate events for a project, derived purely from its badges.
  ///
  /// Pure so it can be tested without a database. Filtering out expiries we
  /// never set up is [record]'s job, since that needs history.
  ///
  /// [userId] only feeds the fingerprint, but it has to: `id` is the table's
  /// primary key, so leaving the account out means the first user to sync a
  /// project silently swallows the notification for everyone else on the
  /// device.
  static List<AppNotification> eventsFor(String userId, ProjectDetail detail) {
    final now = DateTime.now();
    final events = <AppNotification>[];

    for (final badge in detail.badges) {
      switch (badge.availability) {
        case BadgeAvailability.fading:
          events.add(
            AppNotification(
              id: _fingerprint(
                userId,
                detail.id,
                badge.name,
                AppNotificationType.badgeFading,
                // The deadline is part of the identity: if an admin moves it,
                // that's genuinely new information and worth saying again.
                // Re-fading a restored badge announces afresh for free.
                badge.expiresAt?.toIso8601String(),
              ),
              type: AppNotificationType.badgeFading,
              projectId: detail.id,
              subject: badge.name,
              createdAt: now,
              projectName: detail.name,
              fadeReason: badge.fadeReason,
              expiresAt: badge.expiresAt,
            ),
          );

        case BadgeAvailability.expired:
          events.add(
            AppNotification(
              id: _fingerprint(
                userId,
                detail.id,
                badge.name,
                AppNotificationType.badgeExpired,
                badge.expiresAt?.toIso8601String(),
              ),
              type: AppNotificationType.badgeExpired,
              projectId: detail.id,
              subject: badge.name,
              createdAt: now,
              projectName: detail.name,
              fadeReason: badge.fadeReason,
            ),
          );

        case BadgeAvailability.active:
          break;
      }
    }
    return events;
  }

  /// Stable id for one event. Same event on every sync → same id → one row.
  static String _fingerprint(
    String userId,
    String projectId,
    String badgeName,
    AppNotificationType type,
    String? window,
  ) =>
      '$userId|${type.wire}|$projectId|$badgeName|${window ?? ''}';
}
