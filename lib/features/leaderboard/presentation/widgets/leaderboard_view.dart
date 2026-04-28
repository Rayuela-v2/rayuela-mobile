import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/leaderboard.dart';
import '../providers/leaderboard_providers.dart';

/// Per-project leaderboard. Top three rows get medals (🥇🥈🥉) and the
/// row matching the signed-in user is highlighted — the latter is a
/// mobile-specific addition (not present in the web `Leaderboard.vue`)
/// because on a small screen scrolling 50 rows to find yourself feels bad.
///
/// Designed to live inside a `Column` (e.g. inside the "Progress" tab)
/// rather than as a standalone scroll view, so it sets `shrinkWrap: true`
/// and disables its own scroll physics.
class LeaderboardView extends ConsumerWidget {
  const LeaderboardView({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider(projectId));
    final auth = ref.watch(authControllerProvider);
    final currentUserId = switch (auth) {
      AuthStateAuthenticated(:final user) => user.id,
      _ => null,
    };

    return async.when(
      data: (board) => _Body(board: board, currentUserId: currentUserId),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(leaderboardProvider(projectId)),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.board, required this.currentUserId});

  final Leaderboard board;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (board.isEmpty) {
      return EmptyState(
        icon: Icons.leaderboard_outlined,
        title: t.leaderboard_empty_title,
        message: t.leaderboard_empty_body,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in board.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LeaderboardRow(
              entry: entry,
              isCurrentUser:
                  currentUserId != null && entry.userId == currentUserId,
            ),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.isCurrentUser});

  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = isCurrentUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final borderColor = isCurrentUser
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        children: [
          _RankBadge(rank: entry.rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCurrentUser
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      _YouChip(theme: theme),
                    ],
                  ],
                ),
                if (entry.username.trim().isNotEmpty &&
                    entry.username != entry.displayName) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${entry.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCurrentUser
                          ? theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.75)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PointsBadgesPill(
            points: entry.points,
            badgesCount: entry.badgesCount,
            highlighted: isCurrentUser,
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Medal emoji for podium spots — works without bundling extra assets.
    if (rank <= 3) {
      const medals = ['🥇', '🥈', '🥉'];
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Text(medals[rank - 1], style: const TextStyle(fontSize: 24)),
      );
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PointsBadgesPill extends StatelessWidget {
  const _PointsBadgesPill({
    required this.points,
    required this.badgesCount,
    required this.highlighted,
  });

  final int points;
  final int badgesCount;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final fg = highlighted
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final muted = highlighted
        ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 14, color: fg),
            const SizedBox(width: 2),
            Text(
              '$points',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              points == 1 ? t.leaderboard_pt_singular : t.leaderboard_pt_plural,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 12,
              color: muted,
            ),
            const SizedBox(width: 2),
            Text(
              t.leaderboard_badges(badgesCount),
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _YouChip extends StatelessWidget {
  const _YouChip({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        t.leaderboard_you,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontSize: 10,
        ),
      ),
    );
  }
}
