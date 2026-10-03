import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import '../../dashboard/domain/entities/project_detail.dart';

/// Books OS-level reminders for badges that are about to disappear.
///
/// This is the half of the notification centre that works when the app is
/// closed, and it needs no server at all: `expiresAt` is a known instant, so
/// the deadline can simply be booked with the OS the last time the app
/// synced. That's the whole reason this feature doesn't need push — a fading
/// badge is a *scheduled* event, not an unpredictable one.
///
/// Two reminders per badge: a heads-up a few days out, and one at the wire.
class BadgeReminderScheduler {
  BadgeReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Injectable clock so tests don't have to wait for real deadlines.
  final DateTime Function()? now;

  /// How far ahead of the deadline the heads-up fires. Long enough that a
  /// weekend volunteer can still act on it.
  static const Duration headsUp = Duration(days: 3);

  static const String _channelId = 'badge_fading';

  bool _ready = false;
  bool _permissionAsked = false;

  DateTime get _now => now?.call() ?? DateTime.now();

  /// Called when the user taps a reminder while the app is already running.
  /// Set once, by whoever owns navigation.
  void Function(BadgeReminderTarget target)? onTap;

  /// Where the app was launched from, when a tap started it cold.
  ///
  /// Separate from [onTap] because the plugin reports the two cases through
  /// different channels: a tap on a running app fires the callback, a tap
  /// that launches the app does not — it only shows up in the launch
  /// details. Missing this is why "tapping the notification opens the app on
  /// the dashboard" is such a common bug.
  Future<BadgeReminderTarget?> launchTarget() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return BadgeReminderTarget.tryParse(details?.notificationResponse?.payload);
  }

  /// Prepares the plugin. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    // Ships the IANA database with the app so scheduling doesn't depend on
    // whatever the platform happens to expose.
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      onDidReceiveNotificationResponse: (response) {
        final target = BadgeReminderTarget.tryParse(response.payload);
        if (target != null) onTap?.call(target);
      },
      settings: const InitializationSettings(
        // `@mipmap/ic_launcher` is the one icon every Flutter app template
        // already ships, so this needs no extra drawable.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for later, in context — not on first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Re-books every reminder for [detail].
  ///
  /// Cancel-then-schedule rather than diffing: an admin can move a deadline
  /// or restore a badge outright, and re-deriving from scratch is both
  /// shorter and impossible to get out of step with the real window.
  Future<void> sync({
    required ProjectDetail detail,
    required AppLocalizations t,
  }) async {
    final reminders = remindersFor(detail, at: _now);

    // Always clear, even when there is nothing to book: that's what retires
    // the reminders for a badge an admin just restored to active.
    for (final badge in detail.badges) {
      await _cancelFor(detail.id, badge.name);
    }
    if (reminders.isEmpty) return;

    await init();
    if (!await _ensurePermission()) return;

    for (final r in reminders) {
      await _schedule(r, t);
    }
  }

  /// Pure planning step: which reminders should exist for this project right
  /// now. Split out so the timing rules are testable without an OS.
  @visibleForTesting
  static List<BadgeReminder> remindersFor(
    ProjectDetail detail, {
    required DateTime at,
  }) {
    final out = <BadgeReminder>[];
    for (final badge in detail.badges) {
      // Only badges the user can still act on. A badge already earned needs
      // no nagging, and an expired one is not news you can do anything with.
      if (badge.availabilityAt(at) != BadgeAvailability.fading ||
          badge.earned ||
          badge.expiresAt == null) {
        continue;
      }
      final deadline = badge.expiresAt!;

      final heads = deadline.subtract(headsUp);
      // Skip the heads-up when the window is already shorter than it — the
      // final reminder covers that case on its own.
      if (heads.isAfter(at)) {
        out.add(
          BadgeReminder(
            projectId: detail.id,
            projectName: detail.name,
            badgeName: badge.name,
            fireAt: heads,
            isFinalCall: false,
          ),
        );
      }
      if (deadline.isAfter(at)) {
        out.add(
          BadgeReminder(
            projectId: detail.id,
            projectName: detail.name,
            badgeName: badge.name,
            fireAt: deadline,
            isFinalCall: true,
          ),
        );
      }
    }
    return out;
  }

  Future<void> _schedule(BadgeReminder r, AppLocalizations t) async {
    await _plugin.zonedSchedule(
      id: r.notificationId,
      // The deadline is an absolute instant, not a wall-clock rule, so UTC is
      // the honest zone to book it in — it fires at the right moment whatever
      // the device's timezone is, and it survives the user flying somewhere.
      scheduledDate: tz.TZDateTime.from(r.fireAt.toUtc(), tz.UTC),
      title: t.notification_badge_fading_title(r.badgeName),
      body: r.isFinalCall
          ? t.badge_fading_last_call
          : t.notification_badge_fading_body(r.projectName),
      payload: r.payload,
      // Inexact on purpose: exact alarms need a special Android 12+
      // permission users have to grant by hand, and a badge deadline does
      // not need to-the-second precision. A few minutes' drift is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          t.notifications_title,
          channelDescription: t.notifications_empty_hint,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _cancelFor(String projectId, String badgeName) async {
    for (final isFinal in const [false, true]) {
      await _plugin.cancel(
        id: BadgeReminder.idFor(projectId, badgeName, isFinal),
      );
    }
  }

  /// Asks for permission the first time there is genuinely something to
  /// notify about, rather than on first launch. A prompt that arrives with a
  /// reason attached gets said yes to; one that greets a stranger does not.
  Future<bool> _ensurePermission() async {
    if (_permissionAsked) return true;
    _permissionAsked = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }
}

/// What a tapped reminder points at.
@immutable
class BadgeReminderTarget {
  const BadgeReminderTarget({required this.projectId, required this.badgeName});

  final String projectId;
  final String badgeName;

  /// Returns null for anything unrecognisable. A payload written by another
  /// version of the app must open nothing rather than crash the launch path.
  static BadgeReminderTarget? tryParse(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final projectId = map['p'] as String?;
      final badgeName = map['b'] as String?;
      if (projectId == null || projectId.isEmpty) return null;
      return BadgeReminderTarget(
        projectId: projectId,
        badgeName: badgeName ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// One booked reminder.
@immutable
class BadgeReminder {
  const BadgeReminder({
    required this.projectId,
    required this.projectName,
    required this.badgeName,
    required this.fireAt,
    required this.isFinalCall,
  });

  final String projectId;
  final String projectName;
  final String badgeName;
  final DateTime fireAt;

  /// True for the one that fires on the deadline itself.
  final bool isFinalCall;

  int get notificationId => idFor(projectId, badgeName, isFinalCall);

  /// What travels with the notification so a tap can land on the right badge.
  /// JSON rather than a delimiter, because badge names are user-typed and
  /// will eventually contain whatever separator we picked.
  String get payload => jsonEncode({'p': projectId, 'b': badgeName});

  /// Stable 31-bit id derived from the badge, because the OS keys scheduled
  /// notifications by int. Deriving it (rather than storing a counter) is
  /// what lets [BadgeReminderScheduler._cancelFor] retire a reminder it
  /// didn't book itself — after a reinstall, say, or a later app version.
  static int idFor(String projectId, String badgeName, bool isFinalCall) {
    // FNV-1a, masked into positive int32 territory.
    var hash = 0x811c9dc5;
    for (final code in '$projectId|$badgeName|$isFinalCall'.codeUnits) {
      hash = (hash ^ code) * 0x01000193;
      hash &= 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
