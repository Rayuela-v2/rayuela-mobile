import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/locale/locale_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/badge_notification_recorder.dart';
import '../../data/badge_reminder_scheduler.dart';
import '../../data/notifications_dao.dart';
import '../../domain/entities/app_notification.dart';

final notificationsDaoProvider = Provider<NotificationsDao>((ref) {
  return NotificationsDao(ref.watch(appDatabaseProvider).db);
});

final badgeNotificationRecorderProvider =
    Provider<BadgeNotificationRecorder>((ref) {
  return BadgeNotificationRecorder(ref.watch(notificationsDaoProvider));
});

/// Books the OS-level reminders. Long-lived: the plugin keeps its own
/// native state, so re-creating it per use would re-run initialisation.
final badgeReminderSchedulerProvider =
    Provider<BadgeReminderScheduler>((ref) => BadgeReminderScheduler());

/// Localisations for text that has to be rendered without a widget tree —
/// a scheduled notification's title is baked in at booking time, long
/// before it appears, and there is no `BuildContext` in a sync callback.
///
/// Follows the user's picked language, falling back to the system one.
Future<AppLocalizations> resolveLocalizations(Ref ref) {
  final picked = ref.read(localeControllerProvider);
  final system = PlatformDispatcher.instance.locale;
  final locale = picked ??
      (kSupportedLocales.any((l) => l.languageCode == system.languageCode)
          ? Locale(system.languageCode)
          : const Locale('es'));
  return AppLocalizations.delegate.load(locale);
}

/// Signed-in user id, or empty when nobody is. Everything below is scoped by
/// it so two accounts on one device never see each other's notifications.
final notificationsUserIdProvider = Provider<String>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthStateAuthenticated ? state.user.id : '';
});

/// Bumped whenever notifications are written or read, to re-run the queries
/// below. A plain counter beats a stream here: writes come from a sync that
/// already has its own lifecycle, and sqflite has nothing to subscribe to.
final notificationsRevisionProvider = StateProvider<int>((ref) => 0);

/// Everything in the centre, newest first.
final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  ref.watch(notificationsRevisionProvider);
  final userId = ref.watch(notificationsUserIdProvider);
  if (userId.isEmpty) return const [];
  return ref.watch(notificationsDaoProvider).list(userId);
});

/// Drives the bell's badge. Kept separate from the list so the app bar
/// doesn't decode every row just to show a number.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(notificationsRevisionProvider);
  final userId = ref.watch(notificationsUserIdProvider);
  if (userId.isEmpty) return 0;
  return ref.watch(notificationsDaoProvider).unreadCount(userId);
});

/// The one event worth interrupting the user with on this project, if any.
final pendingPopupProvider = FutureProvider.autoDispose
    .family<AppNotification?, String>((ref, projectId) async {
  ref.watch(notificationsRevisionProvider);
  final userId = ref.watch(notificationsUserIdProvider);
  if (userId.isEmpty) return null;
  return ref
      .watch(notificationsDaoProvider)
      .nextUnseen(userId: userId, projectId: projectId);
});

/// Actions. Each one nudges [notificationsRevisionProvider] so the bell and
/// the list refresh without every caller remembering to invalidate.
class NotificationsController {
  const NotificationsController(this._ref);

  final Ref _ref;

  Future<void> markAllRead() async {
    final userId = _ref.read(notificationsUserIdProvider);
    if (userId.isEmpty) return;
    await _ref.read(notificationsDaoProvider).markAllRead(userId);
    _bump();
  }

  /// Marks a popup as delivered so it never interrupts twice.
  Future<void> markSeen(AppNotification notification) async {
    await _ref.read(notificationsDaoProvider).markSeen(notification.id);
    _bump();
  }

  void _bump() => _ref.read(notificationsRevisionProvider.notifier).state++;
}

final notificationsControllerProvider =
    Provider<NotificationsController>((ref) {
  return NotificationsController(ref);
});
