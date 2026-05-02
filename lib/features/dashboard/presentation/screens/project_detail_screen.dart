import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../features/auth/presentation/providers/auth_controller.dart';
import '../../../../features/checkin/presentation/widgets/user_checkins_view.dart';
import '../../../../features/leaderboard/presentation/providers/leaderboard_providers.dart';
import '../../../../features/leaderboard/presentation/widgets/leaderboard_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/project_detail.dart';
import '../providers/project_detail_providers.dart';
import '../widgets/badge_dependency_graph.dart';
import '../widgets/project_areas_map.dart';

/// Single-project deep dive. Mirrors `views/ProjectView.vue` from the web
/// app, scaled down for mobile.
///
/// Subscribed view: header (image + title), description, gamification chip,
/// stats (points, badges earned), tap-through to Tasks, badge grid, and an
/// inline "Unsubscribe" entry at the very bottom (web app does NOT offer
/// this, but on mobile it's the only place users can manage subscriptions).
///
/// Unsubscribed view: same header + description, plus a prominent
/// "Subscribe" button. After a successful subscribe, the screen flips to
/// the subscribed view automatically (provider invalidation).
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.fallbackName,
  });

  final String projectId;

  /// Used as the AppBar title while the detail is loading. The dashboard
  /// already knows the project name; pass it in via the route's
  /// queryParameter so we don't show "Loading..." for half a second.
  final String? fallbackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(projectDetailProvider(projectId));

    final title = Text(
      detailAsync.maybeWhen(
        data: (d) => d.name,
        orElse: () => fallbackName ?? t.project_detail_fallback_title,
      ),
    );

    return detailAsync.when(
      data: (detail) {
        // Tabs are only meaningful once the user is subscribed — that's
        // the point at which "My check-ins" carries content. For the
        // unsubscribed flow we keep the simple single-pane layout to
        // foreground the subscribe CTA.
        if (!detail.isSubscribed) {
          return Scaffold(
            appBar: AppBar(title: title),
            body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(projectDetailProvider(projectId));
                await ref.read(projectDetailProvider(projectId).future);
              },
              child: _OverviewTab(detail: detail),
            ),
          );
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: title,
              bottom: TabBar(
                tabs: [
                  Tab(
                    icon: const Icon(Icons.info_outline),
                    text: t.project_tab_overview,
                  ),
                  Tab(
                    icon: const Icon(Icons.photo_camera_back_outlined),
                    text: t.project_tab_checkins,
                  ),
                  Tab(
                    icon: const Icon(Icons.emoji_events_outlined),
                    text: t.project_tab_progress,
                  ),
                ],
              ),
            ),
            // "Progress" merges the leaderboard and the badges grid/graph
            // — they're both gamification readouts answering "how am I
            // doing?", so keeping them on one tab avoids tab sprawl while
            // freeing Overview for the upcoming check-ins map.
            body: TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(projectDetailProvider(projectId));
                    await ref.read(projectDetailProvider(projectId).future);
                  },
                  child: _OverviewTab(detail: detail),
                ),
                UserCheckinsView(projectId: detail.id),
                _ProgressTab(detail: detail),
              ],
            ),
          ),
        );
      },
      error: (error, _) => Scaffold(
        appBar: AppBar(title: title),
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: ErrorView(
                error: error,
                onRetry: () =>
                    ref.invalidate(projectDetailProvider(projectId)),
              ),
            ),
          ),
        ),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: title),
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.detail});
  final ProjectDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final subscribed = detail.isSubscribed;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _Cover(url: detail.imageUrl),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Project map mirrors the web's GeoMap.vue. Only shown for
              // subscribed users — the unsubscribed view foregrounds the
              // CTA, and a map without check-ins/tasks adds noise.
              if (subscribed && detail.areas.isNotEmpty) ...[
                ProjectAreasMap(
                  projectId: detail.id,
                  areas: detail.areas,
                  onAreaTap: (areaName) => context.pushNamed(
                    AppRoute.tasks,
                    pathParameters: {'projectId': detail.id},
                    queryParameters: {
                      'projectName': detail.name,
                      'areaName': areaName,
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (detail.description.isNotEmpty)
                Text(
                  detail.description,
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 24),
              if (subscribed) ...[
                _StatsRow(projectId: detail.id, stats: detail.user!),
                const SizedBox(height: 16),
                _PrimaryActionButton(
                  icon: Icons.assignment_outlined,
                  label: t.project_view_tasks,
                  onPressed: () => context.pushNamed(
                    AppRoute.tasks,
                    pathParameters: {'projectId': detail.id},
                    queryParameters: {'projectName': detail.name},
                  ),
                ),
                const SizedBox(height: 12),
                _PrimaryActionButton(
                  icon: Icons.add_a_photo_outlined,
                  label: t.project_add_checkin,
                  filled: true,
                  // Pass the project's taskType catalog as `extra` so the
                  // check-in screen can show the chip picker. No taskType
                  // query param — the user picks one on the next screen.
                  onPressed: () => context.pushNamed(
                    AppRoute.checkin,
                    pathParameters: {'projectId': detail.id},
                    queryParameters: {'projectName': detail.name},
                    extra: detail.taskTypes,
                  ),
                ),
                const SizedBox(height: 24),
                _UnsubscribeTile(projectId: detail.id),
              ] else ...[
                _SubscribeButton(projectId: detail.id),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Progress" tab body. Combines the per-project leaderboard (top, since
/// social comparison is the most engaging readout) with the badge catalog
/// (bottom, since it's the long-term goal map). Pulls to refresh both.
class _ProgressTab extends ConsumerWidget {
  const _ProgressTab({required this.detail});
  final ProjectDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider(detail.id));
        ref.invalidate(projectDetailProvider(detail.id));
        await Future.wait([
          ref.read(leaderboardProvider(detail.id).future),
          ref.read(projectDetailProvider(detail.id).future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _SectionHeader(
            icon: Icons.leaderboard_outlined,
            label: t.project_section_leaderboard,
          ),
          const SizedBox(height: 12),
          LeaderboardView(projectId: detail.id),
          if (detail.badges.isNotEmpty) ...[
            const SizedBox(height: 28),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            _BadgesSection(badges: detail.badges),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (url == null || url!.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.image_outlined, size: 64, color: Colors.white54),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
      ),
    );
  }
}

/// Three big tiles: points, badges earned, and (when known) live leaderboard
/// rank. The rank tile is wired to `leaderboardProvider` so the user gets a
/// real "#3" instead of the static null on `ProjectUserStats.leaderboardRank`.
/// While the leaderboard is loading or errored we just hide the rank tile —
/// it's a nice-to-have, not a blocker for the rest of the row.
class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.projectId, required this.stats});
  final String projectId;
  final ProjectUserStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    // Resolve the live rank: leaderboard says X, otherwise fall back to
    // whatever shipped on the project payload (currently always null).
    final leaderboardAsync = ref.watch(leaderboardProvider(projectId));
    final auth = ref.watch(authControllerProvider);
    final liveRank = leaderboardAsync.maybeWhen(
      data: (board) {
        final userId = switch (auth) {
          AuthStateAuthenticated(:final user) => user.id,
          _ => null,
        };
        if (userId == null) return null;
        return board.entryForUser(userId)?.rank;
      },
      orElse: () => null,
    );
    final rank = liveRank ?? stats.leaderboardRank;

    return Row(
      children: [
        _StatTile(
          icon: Icons.stars_rounded,
          label: t.project_stat_points,
          value: stats.points.toString(),
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.emoji_events_outlined,
          label: t.project_stat_badges,
          value: stats.badgesEarned.toString(),
          color: theme.colorScheme.tertiary,
        ),
        if (rank != null) ...[
          const SizedBox(width: 12),
          _StatTile(
            icon: Icons.leaderboard_outlined,
            label: t.project_stat_rank,
            value: '#$rank',
            color: theme.colorScheme.secondary,
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: filled
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

/// Header + view toggle for the badges block. Defaults to the grid (matches
/// the rest of the screen's visual rhythm), and exposes a graph view when
/// the catalog has any dependency edges — same affordance as the web app's
/// `<BadgeDependencyGraph>`.
class _BadgesSection extends StatefulWidget {
  const _BadgesSection({required this.badges});
  final List<ProjectBadge> badges;

  @override
  State<_BadgesSection> createState() => _BadgesSectionState();
}

class _BadgesSectionState extends State<_BadgesSection> {
  bool _showGraph = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    // Only offer the toggle when the graph would actually have edges,
    // otherwise it's an empty, confusing canvas.
    final hasEdges =
        widget.badges.any((b) => b.previousBadges.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.project_section_badges,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (hasEdges)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.grid_view_rounded, size: 18),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.account_tree_outlined, size: 18),
                  ),
                ],
                selected: {_showGraph},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _showGraph = s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showGraph && hasEdges)
          _BadgeGraphCard(badges: widget.badges)
        else
          _BadgeGrid(badges: widget.badges),
      ],
    );
  }
}

/// Wraps [BadgeDependencyGraph] in a horizontally-scrollable card. The
/// graph computes its own intrinsic size; tall projects with many layers
/// stay vertically scrollable along with the rest of the screen.
class _BadgeGraphCard extends StatelessWidget {
  const _BadgeGraphCard({required this.badges});
  final List<ProjectBadge> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > 16 ? constraints.maxWidth - 16 : 0,
            ),
            child: Center(
              child: BadgeDependencyGraph(
                badges: badges,
                onBadgeTap: (b) => _showBadgeSheet(context, b),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBadgeSheet(BuildContext context, ProjectBadge badge) {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              badge.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.earned ? t.badge_earned : t.badge_locked,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: badge.earned
                        ? const Color(0xFF2E7D32)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (badge.description != null) ...[
              const SizedBox(height: 12),
              Text(
                badge.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (badge.previousBadges.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                t.badge_requires,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in badge.previousBadges)
                    Chip(label: Text(p), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges});
  final List<ProjectBadge> badges;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: badges.length,
      itemBuilder: (context, i) => _BadgeTile(badge: badges[i]),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});
  final ProjectBadge badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = badge.earned;
    final color =
        earned ? theme.colorScheme.tertiary : theme.colorScheme.outline;

    return InkWell(
      onTap: () => _show(context),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // Earned badges get a subtle gradient + glow so they pop visually.
          // Inspired by the web app's green/checkmark styling for active badges.
          gradient: earned
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.05),
                  ],
                )
              : null,
          color: earned ? null : color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: earned ? 0.5 : 0.15),
            width: earned ? 1.5 : 1,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _BadgeMedia(
                        key: ValueKey(badge.imageUrl),
                        imageUrl: badge.imageUrl,
                        earned: earned,
                        color: color,
                        size: constraints.biggest.shortestSide,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  badge.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: earned
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (earned)
              // Tiny "earned" checkmark in the corner — mirrors the web app.
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 12,
                    color: theme.colorScheme.onTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final t = AppLocalizations.of(sheetCtx)!;
        final earned = badge.earned;
        final color =
            earned ? theme.colorScheme.tertiary : theme.colorScheme.outline;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: _BadgeMedia(
                  key: ValueKey(badge.imageUrl),
                  imageUrl: badge.imageUrl,
                  earned: earned,
                  color: color,
                  size: 64,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                badge.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4,),
                decoration: BoxDecoration(
                  color: earned
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  earned ? t.badge_earned : t.badge_locked,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: earned
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badge.description != null &&
                  badge.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  badge.description!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Renders a circular badge medium. Falls back to a trophy icon if there
/// is no image. Earned badges keep full color; locked ones desaturate.
class _BadgeMedia extends StatelessWidget {
  const _BadgeMedia({
    super.key,
    required this.imageUrl,
    required this.earned,
    required this.color,
    this.size = 36,
  });

  final String? imageUrl;
  final bool earned;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Icon(
        earned ? Icons.emoji_events : Icons.emoji_events_outlined,
        size: size * 0.9,
        color: color,
      );
    }

    Widget image;
    if (imageUrl!.startsWith('data:image/')) {
      try {
        final base64String = imageUrl!.split(',').last;
        image = Image.memory(
          base64Decode(base64String),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            earned ? Icons.emoji_events : Icons.emoji_events_outlined,
            size: size * 0.9,
            color: color,
          ),
        );
      } catch (e) {
        image = Icon(
          earned ? Icons.emoji_events : Icons.emoji_events_outlined,
          size: size * 0.9,
          color: color,
        );
      }
    } else {
      image = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Icon(
          earned ? Icons.emoji_events : Icons.emoji_events_outlined,
          size: size * 0.9,
          color: color,
        ),
      );
    }

    final clipped = ClipOval(child: image);
    if (earned) return clipped;
    // Desaturate locked badges so the earned ones visually win.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 0.6, 0,
      ]),
      child: clipped,
    );
  }
}

class _SubscribeButton extends ConsumerWidget {
  const _SubscribeButton({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final state = ref.watch(subscriptionToggleControllerProvider);
    final inFlight = state is SubscriptionInFlight;

    // Surface failures via SnackBar — listen, don't rebuild on it.
    ref.listen(subscriptionToggleControllerProvider, (prev, next) {
      if (next is SubscriptionFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: inFlight
            ? null
            : () async {
                final ok = await ref
                    .read(subscriptionToggleControllerProvider.notifier)
                    .toggle(projectId);
                if (!context.mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.project_subscribed_success)),
                  );
                }
              },
        icon: inFlight
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_circle_outline),
        label: Text(inFlight ? t.project_subscribing : t.project_subscribe),
      ),
    );
  }
}

class _UnsubscribeTile extends ConsumerWidget {
  const _UnsubscribeTile({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final state = ref.watch(subscriptionToggleControllerProvider);
    final inFlight = state is SubscriptionInFlight;
    final theme = Theme.of(context);

    ref.listen(subscriptionToggleControllerProvider, (prev, next) {
      if (next is SubscriptionFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.logout,
          color: theme.colorScheme.onErrorContainer,
        ),
        title: Text(t.project_unsubscribe),
        subtitle: Text(t.project_unsubscribe_subtitle),
        trailing: inFlight
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: inFlight ? null : () => _confirm(context, ref),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.project_unsubscribe_confirm_title),
        content: Text(t.project_unsubscribe_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common_cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.common_unsubscribe),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(subscriptionToggleControllerProvider.notifier)
        .toggle(projectId);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.project_unsubscribe_success)),
      );
    }
  }
}
