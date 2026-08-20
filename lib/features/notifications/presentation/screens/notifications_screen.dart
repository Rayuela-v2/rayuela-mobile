import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_providers.dart';
import '../widgets/notification_copy.dart';

/// The notification centre: everything the app has told this user, newest
/// first. Opening it marks the backlog read — the bell's job is to say
/// "there's something new", and by now they've looked.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Snapshot of what was unread when the screen opened, so the list can keep
  /// highlighting those rows after we've flipped them to read in storage.
  Set<String>? _unreadOnEntry;

  /// Latches the one write we do on entry.
  ///
  /// Without it this screen spins: `markAllRead` bumps the notifications
  /// revision, the list provider re-runs, build fires again, and schedules
  /// another `markAllRead`. That loop repaints every frame, which is what
  /// made the screen flicker and swallow taps the first time it opened with
  /// anything unread.
  bool _markedRead = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.notifications_title)),
      body: async.when(
        loading: LoadingView.new,
        error: (_, __) => EmptyState(
          icon: Icons.notifications_off_outlined,
          title: t.notifications_empty,
          message: t.notifications_empty_hint,
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none,
              title: t.notifications_empty,
              message: t.notifications_empty_hint,
            );
          }

          _unreadOnEntry ??= {
            for (final n in items)
              if (!n.isRead) n.id,
          };
          if (_unreadOnEntry!.isNotEmpty && !_markedRead) {
            _markedRead = true;
            // After the frame so we're not writing during a build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(notificationsControllerProvider).markAllRead();
            });
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _NotificationTile(
              notification: items[i],
              highlight: _unreadOnEntry!.contains(items[i].id),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({
    required this.notification,
    required this.highlight,
  });

  final AppNotification notification;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final fading = notification.type == AppNotificationType.badgeFading;
    // Amber only while the deadline is still ahead. A fading notice whose
    // window has since closed is history, and colouring history as urgent
    // teaches people to ignore the colour.
    final live = fading && notification.windowStillOpen;
    final accent =
        live ? RayuelaColors.warning : theme.colorScheme.onSurfaceVariant;
    final countdown = notification.countdown(t);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      tileColor: highlight
          ? theme.colorScheme.primary.withValues(alpha: 0.05)
          : null,
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.15),
        child: Icon(
          fading ? Icons.hourglass_bottom : Icons.block,
          color: accent,
          size: 20,
        ),
      ),
      title: Text(
        notification.title(t),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(notification.body(t)),
          if (countdown != null) ...[
            const SizedBox(height: 4),
            Text(
              countdown,
              style: theme.textTheme.labelMedium?.copyWith(
                color: RayuelaColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (notification.fadeReason != null &&
              notification.fadeReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notification.fadeReason!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        // Tapping the notice is engaging with it, so it must not also pop up
        // as an interruption the moment the project opens.
        if (!notification.isSeen) {
          ref.read(notificationsControllerProvider).markSeen(notification);
        }
        // Land on the badge itself. Opening the project and leaving the user
        // to find the badge among twenty is not "see badge".
        context.pushNamed(
          AppRoute.projectDetail,
          pathParameters: {'projectId': notification.projectId},
          queryParameters: {
            'badge': notification.subject,
            if (notification.projectName != null)
              'projectName': notification.projectName!,
          },
        );
      },
    );
  }
}
