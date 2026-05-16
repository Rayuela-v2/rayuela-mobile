import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/sync/outbox/sync_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/outbox_providers.dart';

/// Compact AppBar action that reflects the outbox sync state.
///
/// Visibility:
///   * `idle` (default) → renders nothing (returns `SizedBox.shrink`).
///   * `offline`        → cloud-off icon, neutral colour.
///   * `syncing`        → spinning icon.
///   * `error`          → amber outline icon, taps into "Pending data".
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final status = ref.watch(syncStatusProvider).valueOrNull ?? SyncStatus.idle;

    if (status == SyncStatus.idle) return const SizedBox.shrink();

    final (icon, label, color) = switch (status) {
      SyncStatus.offline => (
          Icons.cloud_off_outlined,
          t.dashboard_sync_status_offline,
          theme.colorScheme.onSurfaceVariant,
        ),
      SyncStatus.syncing => (
          Icons.sync,
          t.dashboard_sync_status_syncing,
          theme.colorScheme.primary,
        ),
      SyncStatus.error => (
          Icons.warning_amber_outlined,
          t.dashboard_sync_status_error,
          theme.colorScheme.tertiary,
        ),
      // Already short-circuited above.
      SyncStatus.idle => (Icons.cloud_done, '', theme.colorScheme.primary),
    };

    return IconButton(
      tooltip: label,
      icon: Icon(icon, color: color),
      onPressed: () => context.pushNamed(AppRoute.pendingData),
    );
  }
}

/// Banner-style summary that headlines the dashboard when there are
/// queued check-ins. Tap to open the "Pending data" screen.
class OutboxBanner extends ConsumerWidget {
  const OutboxBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final count = ref.watch(pendingCheckinCountProvider).valueOrNull ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final label = count == 1
        ? t.dashboard_outbox_banner_one
        : t.dashboard_outbox_banner_many(count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.pushNamed(AppRoute.pendingData),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t.dashboard_outbox_banner_action,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
