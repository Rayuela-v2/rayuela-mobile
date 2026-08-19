import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_providers.dart';
import 'notification_copy.dart';

/// Shows the one pending event for a project as a dialog, at most once.
///
/// The rules that keep this from becoming nagging, all deliberate:
///
///   * Only *transitions* pop. The tile that breathes on the badge grid is
///     the permanent ambient signal; a modal on every project open for a
///     state the user already knows about would get this muted in a week.
///   * One per open. `seen_at` is written the moment it's shown, so even a
///     backlog of three fading badges interrupts once.
///   * Dismissing counts as delivered. Someone who taps "later" has read the
///     headline — that was the job.
///
/// Returns the badge name the user asked to be taken to, or null if they
/// dismissed it. The caller owns the navigation, because "go to the badge"
/// means different things depending on where the popup was raised from.
Future<String?> showPendingBadgePopup(
  BuildContext context,
  WidgetRef ref, {
  required AppNotification pending,
}) async {
  // Written before the dialog rather than after: if the app is killed while
  // it's open, we'd rather lose one notice than re-interrupt on every launch.
  await ref.read(notificationsControllerProvider).markSeen(pending);
  if (!context.mounted) return null;

  final t = AppLocalizations.of(context)!;
  final fading = pending.type == AppNotificationType.badgeFading;
  final countdown = pending.countdown(t);

  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      icon: Icon(
        fading ? Icons.hourglass_bottom : Icons.block,
        size: 36,
        color: fading
            ? RayuelaColors.warning
            : Theme.of(dialogCtx).colorScheme.onSurfaceVariant,
      ),
      title: Text(pending.title(t), textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pending.body(t), textAlign: TextAlign.center),
          if (countdown != null) ...[
            const SizedBox(height: 12),
            Text(
              countdown,
              textAlign: TextAlign.center,
              style: Theme.of(dialogCtx).textTheme.titleMedium?.copyWith(
                    color: RayuelaColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (pending.fadeReason != null && pending.fadeReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              pending.fadeReason!,
              textAlign: TextAlign.center,
              style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogCtx).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(t.notification_popup_later),
        ),
        FilledButton(
          // Hands the badge name back so the caller can open its sheet.
          // "See badge" has to actually show the badge — the project screen
          // behind the dialog is not what the button promises.
          onPressed: () => Navigator.of(dialogCtx).pop(pending.subject),
          child: Text(t.notification_popup_go),
        ),
      ],
    ),
  );
}
