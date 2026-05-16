import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/sync/outbox/outbox_entry.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/checkin_history_item.dart';
import '../providers/checkin_providers.dart';
import '../providers/outbox_providers.dart';
import '../utils/checkin_image_url.dart';
import 'checkin_image_viewer.dart';
import 'pending_checkin_tile.dart';

/// "My check-ins" tab body for the project detail screen. Pulls
/// `userCheckinsProvider(projectId)` and renders one [_CheckinCard] per
/// entry, newest first.
///
/// Supports pull-to-refresh; the provider is auto-disposing so leaving the
/// screen drops the in-memory list.
class UserCheckinsView extends ConsumerWidget {
  const UserCheckinsView({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userCheckinsProvider(projectId));
    // Pending stream is scoped to this project so the section above the
    // server-synced history only shows the rows the user expects to see
    // here. It auto-disposes when the tab is dismissed.
    final pending =
        ref.watch(pendingCheckinsProvider(projectId)).valueOrNull ??
            const <OutboxEntry>[];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userCheckinsProvider(projectId));
        await ref.read(userCheckinsProvider(projectId).future);
      },
      child: async.when(
        data: (items) => _Body(
          projectId: projectId,
          items: items,
          pending: pending,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(userCheckinsProvider(projectId)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.projectId,
    required this.items,
    required this.pending,
  });

  final String projectId;
  final List<CheckinHistoryItem> items;
  final List<OutboxEntry> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    if (items.isEmpty && pending.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: EmptyState(
              icon: Icons.photo_camera_back_outlined,
              title: t.checkins_empty_title,
              message: t.checkins_empty_body,
            ),
          ),
        ),
      );
    }

    // Group synced items by day for a friendlier scan. The frontend
    // doesn't bother but mobile screens are skinny and a date header
    // helps keep the eye anchored.
    final byDay = <String, List<CheckinHistoryItem>>{};
    final dayLabel = DateFormat.yMMMMd();
    for (final item in items) {
      final key = dayLabel.format(item.datetime.toLocal());
      (byDay[key] ??= []).add(item);
    }
    final sections = byDay.entries.toList(growable: false);
    final hasPending = pending.isNotEmpty;
    // 1 leading section for "Waiting to sync" if pending, plus one per
    // synced day.
    final totalSections = sections.length + (hasPending ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: totalSections,
      itemBuilder: (context, index) {
        if (hasPending && index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateHeader(label: t.outbox_section_pending),
              const SizedBox(height: 8),
              for (final entry in pending) ...[
                PendingCheckinTile(
                  entry: entry,
                  onRetry: entry.status == OutboxStatus.dead
                      ? () => _retry(ref, entry.id)
                      : null,
                  onDiscard: entry.status == OutboxStatus.dead
                      ? () => _confirmDiscard(context, ref, entry.id)
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        final sectionIndex = hasPending ? index - 1 : index;
        final section = sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sectionIndex > 0 || hasPending) const SizedBox(height: 12),
            _DateHeader(label: section.key),
            const SizedBox(height: 8),
            for (final item in section.value) ...[
              _CheckinCard(item: item),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  void _retry(WidgetRef ref, String id) {
    // Fire-and-forget: the pendingCheckinsProvider stream will pick up
    // the resulting state change and rebuild the tile.
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

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({required this.item});

  final CheckinHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final timeLabel = DateFormat.jm().format(item.datetime.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.imageRefs.isNotEmpty)
            _ImageStrip(imageRefs: item.imageRefs),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (item.solvesATask)
                      _TaskSolvedChip(name: item.contributesToTaskName),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.taskType.isEmpty ? t.checkins_card_default_kind : item.taskType,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.hasLocation) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatLatLng(item),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLatLng(CheckinHistoryItem item) {
    final lat = double.tryParse(item.latitude ?? '');
    final lng = double.tryParse(item.longitude ?? '');
    if (lat == null || lng == null) {
      return '${item.latitude}, ${item.longitude}';
    }
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}

class _TaskSolvedChip extends StatelessWidget {
  const _TaskSolvedChip({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt,
            size: 12,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            (name == null || name!.isEmpty)
                ? t.checkins_task_solved
                : t.checkins_task_solved_named(name!),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top of the card: 1, 2, or 3 photos. The first photo is large; any
/// additional ones tile to the right with a "+N more" overlay if there are
/// more than two extras. Tapping any photo opens the [CheckinImageViewer].
class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.imageRefs});
  final List<String> imageRefs;

  @override
  Widget build(BuildContext context) {
    final main = imageRefs.first;
    final extras = imageRefs.skip(1).toList(growable: false);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              flex: extras.isEmpty ? 1 : 2,
              child: _Thumb(
                ref: main,
                onTap: () => CheckinImageViewer.push(
                  context,
                  imageRefs: imageRefs,
                ),
              ),
            ),
            if (extras.isNotEmpty) ...[
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _Thumb(
                        ref: extras.first,
                        onTap: () => CheckinImageViewer.push(
                          context,
                          imageRefs: imageRefs,
                          initialIndex: 1,
                        ),
                      ),
                    ),
                    if (extras.length > 1) ...[
                      const SizedBox(height: 2),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _Thumb(
                              ref: extras[1],
                              onTap: () => CheckinImageViewer.push(
                                context,
                                imageRefs: imageRefs,
                                initialIndex: 2,
                              ),
                            ),
                            if (extras.length > 2)
                              IgnorePointer(
                                child: Container(
                                  color: Colors.black54,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+${extras.length - 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.ref, required this.onTap});
  final String ref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = resolveCheckinImageUrl(ref);
    return InkWell(
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}
