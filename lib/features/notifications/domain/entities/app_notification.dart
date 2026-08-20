import 'dart:convert';

/// Kinds of notification the app can raise.
///
/// The wire value is what lands in the `type` column, so these strings are
/// storage format: renaming one orphans every row already written. Add
/// members freely; don't rewrite existing values.
enum AppNotificationType {
  /// A badge entered its fading window — still earnable, but on a clock.
  badgeFading('badge_fading'),

  /// A badge's window closed. Nobody new can earn it.
  badgeExpired('badge_expired');

  const AppNotificationType(this.wire);
  final String wire;

  /// Unknown values (a row written by a newer build, then downgraded) come
  /// back as null so the centre can skip them instead of crashing.
  static AppNotificationType? fromWire(String? value) {
    for (final t in AppNotificationType.values) {
      if (t.wire == value) return t;
    }
    return null;
  }
}

/// One entry in the notification centre.
///
/// Carries structured data, never rendered text: the user can switch language
/// at any time, and a Spanish string frozen into the database would still be
/// Spanish afterwards. Screens render [type] + [subject] + [data] through
/// `AppLocalizations` at display time.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.projectId,
    required this.subject,
    required this.createdAt,
    this.projectName,
    this.fadeReason,
    this.expiresAt,
    this.readAt,
    this.seenAt,
  });

  /// Deterministic fingerprint of the underlying event — see
  /// [BadgeNotificationRecorder]. Doubles as the dedupe key.
  final String id;
  final AppNotificationType type;
  final String projectId;

  /// What the notification is about. A badge name today.
  final String subject;

  final DateTime createdAt;
  final String? projectName;
  final String? fadeReason;

  /// Deadline of the fading window, for the countdown. Null on expiry rows.
  final DateTime? expiresAt;

  /// Set once the user opened the centre and saw this row listed.
  final DateTime? readAt;

  /// Set once this event was surfaced as a popup, so it only interrupts once.
  final DateTime? seenAt;

  bool get isRead => readAt != null;
  bool get isSeen => seenAt != null;

  /// True while the deadline is still ahead — the only case where showing a
  /// live countdown makes sense. A row in the centre outlives its window.
  bool get windowStillOpen =>
      expiresAt != null && expiresAt!.isAfter(DateTime.now());

  Map<String, Object?> toRow(String userId) => {
        'id': id,
        'user_id': userId,
        'type': type.wire,
        'project_id': projectId,
        'subject': subject,
        'data_json': jsonEncode({
          if (projectName != null) 'projectName': projectName,
          if (fadeReason != null) 'fadeReason': fadeReason,
          if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        }),
        'created_at': createdAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'seen_at': seenAt?.toIso8601String(),
      };

  /// Returns null for rows this build can't interpret rather than throwing —
  /// one unreadable row must not take the whole centre down.
  static AppNotification? fromRow(Map<String, Object?> row) {
    final type = AppNotificationType.fromWire(row['type'] as String?);
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    if (type == null || createdAt == null) return null;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(row['data_json'] as String? ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      data = const {};
    }

    return AppNotification(
      id: row['id'] as String,
      type: type,
      projectId: row['project_id'] as String? ?? '',
      subject: row['subject'] as String? ?? '',
      createdAt: createdAt,
      projectName: data['projectName'] as String?,
      fadeReason: data['fadeReason'] as String?,
      expiresAt: DateTime.tryParse(data['expiresAt'] as String? ?? ''),
      readAt: DateTime.tryParse(row['read_at'] as String? ?? ''),
      seenAt: DateTime.tryParse(row['seen_at'] as String? ?? ''),
    );
  }
}
