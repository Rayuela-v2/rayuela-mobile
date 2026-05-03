import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/sync/outbox/outbox_entry.dart';
import '../../../../l10n/app_localizations.dart';

/// Card representation of one queued [OutboxEntry].
///
/// Mirrors the visual language of the synced check-in card so the two
/// kinds sit comfortably in the same list: same photo strip on top, same
/// metadata row at the bottom, plus a status pill and (when relevant) a
/// row of `Retry now` / `Discard` actions.
///
/// Renders local files via [Image.file] — the photos live in the app's
/// private support directory until the drainer uploads them.
class PendingCheckinTile extends StatelessWidget {
  const PendingCheckinTile({
    super.key,
    required this.entry,
    this.onRetry,
    this.onDiscard,
    this.dense = false,
  });

  final OutboxEntry entry;

  /// `null` hides the action button (e.g. for the inline list inside the
  /// project detail tab where actions live in the dedicated screen).
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  /// `true` renders a tighter layout for the global "Pending data" list.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final timeLabel = DateFormat.jm().format(
      entry.clientCapturedAt.toLocal(),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _accentColor(theme, entry.status).withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.images.isNotEmpty && !dense)
            _LocalImageStrip(images: entry.images),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusPill(status: entry.status),
                    const SizedBox(width: 8),
                    if (entry.attemptCount > 0)
                      Text(
                        t.outbox_attempt_count(entry.attemptCount),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.taskType,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
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
                        '${entry.latitude}, ${entry.longitude}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (entry.lastErrorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.lastErrorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (onRetry != null || onDiscard != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onDiscard != null)
                        TextButton.icon(
                          onPressed: onDiscard,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(t.outbox_action_discard),
                        ),
                      if (onRetry != null) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.sync, size: 18),
                          label: Text(t.outbox_action_retry),
                        ),
                      ],
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

  static Color _accentColor(ThemeData theme, OutboxStatus status) {
    return switch (status) {
      OutboxStatus.pending ||
      OutboxStatus.inflight =>
        theme.colorScheme.tertiary,
      OutboxStatus.failed => theme.colorScheme.secondary,
      OutboxStatus.dead => theme.colorScheme.error,
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OutboxStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final (label, fg, bg) = switch (status) {
      OutboxStatus.pending => (
          t.outbox_status_pending,
          theme.colorScheme.onTertiaryContainer,
          theme.colorScheme.tertiaryContainer,
        ),
      OutboxStatus.inflight => (
          t.outbox_status_inflight,
          theme.colorScheme.onPrimaryContainer,
          theme.colorScheme.primaryContainer,
        ),
      OutboxStatus.failed => (
          t.outbox_status_retrying,
          theme.colorScheme.onSecondaryContainer,
          theme.colorScheme.secondaryContainer,
        ),
      OutboxStatus.dead => (
          t.outbox_status_failed,
          theme.colorScheme.onErrorContainer,
          theme.colorScheme.errorContainer,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Renders 1-3 local images on top of the tile in the same shape as the
/// synced [_ImageStrip] in `user_checkins_view.dart` — kept minimal here
/// (no zoom dialog) because pending check-ins aren't tappable yet.
class _LocalImageStrip extends StatelessWidget {
  const _LocalImageStrip({required this.images});
  final List<OutboxImage> images;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: 160,
        child: Row(
          children: [
            for (var i = 0; i < images.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: _LocalThumb(
                  path: images[i].filePath,
                  fallbackColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocalThumb extends StatelessWidget {
  const _LocalThumb({required this.path, required this.fallbackColor});
  final String path;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final f = File(path);
    return Image.file(
      f,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: fallbackColor,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
