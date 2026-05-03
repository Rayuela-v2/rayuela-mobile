import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/outbox/outbox_entry.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/outbox_providers.dart';
import '../widgets/pending_checkin_tile.dart';

/// "Datos pendientes" — global view of every queued/failed/dead check-in
/// for the current user, grouped by project. Reachable from the
/// dashboard banner and (eventually) from Profile / Settings.
///
/// Data source: [pendingCheckinsProvider] without a project filter.
class PendingDataScreen extends ConsumerWidget {
  const PendingDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    // null projectId → all projects.
    final pendingAsync = ref.watch(pendingCheckinsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pending_data_title),
        actions: [
          // Best-effort: trigger a drain manually. The button stays
          // visible even when the queue is empty so the affordance is
          // discoverable; the OutboxService no-ops if there's nothing
          // to do.
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: t.outbox_action_retry_all,
            onPressed: () => _retryAll(ref),
          ),
        ],
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString()),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.cloud_done_outlined,
                title: t.pending_data_empty_title,
                message: t.pending_data_empty_body,
              ),
            );
          }
          // Group by project so the user can scan by context. We don't
          // have a projects-by-id lookup in this screen, so fall back to
          // the project id as the section label — a future iteration can
          // join with cached_projects to show the readable name.
          final byProject = <String, List<OutboxEntry>>{};
          for (final e in entries) {
            (byProject[e.projectId] ??= []).add(e);
          }
          final sections = byProject.entries.toList(growable: false);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: sections.length,
            itemBuilder: (context, sectionIndex) {
              final section = sections[sectionIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sectionIndex > 0) const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      t.pending_data_project_label(section.key),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  for (final entry in section.value) ...[
                    PendingCheckinTile(
                      entry: entry,
                      onRetry: () => _retry(ref, entry.id),
                      onDiscard: () => _confirmDiscard(context, ref, entry.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _retryAll(WidgetRef ref) {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthStateAuthenticated) return;
    // ignore: unawaited_futures
    ref.read(outboxServiceProvider).drain(userId: auth.user.id);
  }

  void _retry(WidgetRef ref, String id) {
    // ignore: unawaited_futures
    ref.read(outboxServiceProvider).retry(id);
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.outbox_discard_confirm_title),
        content: Text(t.outbox_discard_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.outbox_cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.outbox_discard_confirm_cta),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(outboxServiceProvider).discard(id);
    }
  }
}
