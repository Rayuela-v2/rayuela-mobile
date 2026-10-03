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
import '../../../../features/notifications/domain/entities/app_notification.dart';
import '../../../../features/notifications/presentation/providers/notifications_providers.dart';
import '../../../../features/notifications/presentation/widgets/badge_fading_popup.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/linkified_text.dart';
import '../../domain/entities/project_detail.dart';
import '../providers/project_detail_providers.dart';
import '../widgets/badge_dependency_graph.dart';
import '../widgets/badge_fade_effect.dart';
import '../widgets/badge_status_look.dart';
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
    this.focusBadge,
  });

  final String projectId;

  /// Used as the AppBar title while the detail is loading. The dashboard
  /// already knows the project name; pass it in via the route's
  /// queryParameter so we don't show "Loading..." for half a second.
  final String? fallbackName;

  /// Name of a badge to open the detail sheet for once the project loads.
  /// Set by the `?badge=` query parameter, which is how the notification
  /// centre lands the user on the badge it was actually talking about
  /// instead of dumping them on the project and making them hunt for it.
  final String? focusBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(projectDetailProvider(projectId));

    final title = Text(
      detailAsync.maybeWhen(
        data: (cached) => cached.value.name,
        orElse: () => fallbackName ?? t.project_detail_fallback_title,
      ),
    );

    return detailAsync.when(
      data: (cached) {
        final detail = cached.value;
        // Tabs are only meaningful once the user is subscribed — that's
        // the point at which "My check-ins" carries content. For the
        // unsubscribed flow we keep the simple single-pane layout to
        // foreground the subscribe CTA.
        if (!detail.isSubscribed) {
          return Scaffold(
            appBar: AppBar(title: title),
            body: RefreshIndicator(
              onRefresh: () async {
                try {
                  await ref.read(refreshProjectDetailProvider)(projectId);
                } catch (_) {/* surfaces via AsyncError below */}
              },
              child: _OverviewTab(detail: detail),
            ),
          );
        }
        return _SubscribedProjectView(
          detail: detail,
          title: title,
          focusBadge: focusBadge,
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

/// Subscribed project view: the 3-tab layout plus a floating "add check-in"
/// button. The FAB is shown on every tab and only hidden when the full-width
/// "Agregar un check-in" button is actually on screen (bottom of Overview),
/// so the primary action is always one tap away without ever duplicating a
/// visible control.
class _SubscribedProjectView extends ConsumerStatefulWidget {
  const _SubscribedProjectView({
    required this.detail,
    required this.title,
    this.focusBadge,
  });

  final ProjectDetail detail;
  final Widget title;
  final String? focusBadge;

  @override
  ConsumerState<_SubscribedProjectView> createState() =>
      _SubscribedProjectViewState();
}

class _SubscribedProjectViewState
    extends ConsumerState<_SubscribedProjectView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey _checkinButtonKey = GlobalKey();

  int _tabIndex = 0;
  bool _inlineButtonVisible = false;

  /// One interruption per visit, however many times the pending-popup
  /// provider re-emits underneath us.
  bool _popupHandled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _tabIndex) {
        setState(() => _tabIndex = _tabController.index);
      }
    });

    // Deep link from the notification centre: open the badge it was about.
    // After the first frame, not during it — this pushes a route.
    final focus = widget.focusBadge;
    if (focus != null && focus.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openBadge(focus));
    }
  }

  /// Opens the detail sheet for a badge by name, if the catalog still has
  /// one. A renamed or deleted badge just means no sheet — never a crash.
  void _openBadge(String name) {
    if (!mounted) return;
    for (final badge in widget.detail.badges) {
      if (badge.name == name) {
        _showBadgeDetails(context, badge);
        return;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onInlineButtonVisibilityChanged(bool visible) {
    if (visible != _inlineButtonVisible && mounted) {
      setState(() => _inlineButtonVisible = visible);
    }
  }

  // Hidden only when the inline button is on screen (Overview tab, scrolled to
  // the bottom). On the other tabs the inline button isn't mounted, so the FAB
  // always shows.
  bool get _showFab => !(_tabIndex == 0 && _inlineButtonVisible);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final detail = widget.detail;

    // Watched, not a one-shot at mount: the notification is written by the
    // sync this very screen kicks off, so checking once on the first frame
    // loses the race and the popup only turns up on some later visit.
    // Watching covers both orderings — already pending, or arriving after.
    final AppNotification? pending =
        ref.watch(pendingPopupProvider(detail.id)).asData?.value;
    if (pending != null && !_popupHandled) {
      // Latch during build so a rebuild can't queue a second dialog.
      _popupHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showPendingBadgePopup(context, ref, pending: pending).then((goTo) {
          if (goTo != null) _openBadge(goTo);
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: widget.title,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.home_outlined),
              text: t.project_tab_overview,
            ),
            Tab(
              icon: const Icon(Icons.menu_book_outlined),
              text: t.project_tab_checkins,
            ),
            Tab(
              icon: const Icon(Icons.emoji_events_outlined),
              text: t.project_tab_progress,
            ),
          ],
        ),
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              tooltip: t.project_add_checkin,
              onPressed: () => _openCheckin(context, detail),
              child: const Icon(Icons.post_add),
            )
          : null,
      // "Progress" merges the leaderboard and the badges grid/graph — they're
      // both gamification readouts answering "how am I doing?", so keeping them
      // on one tab avoids tab sprawl while freeing Overview for the map.
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: () async {
              try {
                await ref.read(refreshProjectDetailProvider)(detail.id);
              } catch (_) {/* surfaces via AsyncError elsewhere */}
            },
            child: _OverviewTab(
              detail: detail,
              checkinButtonKey: _checkinButtonKey,
              onCheckinButtonVisibilityChanged:
                  _onInlineButtonVisibilityChanged,
            ),
          ),
          UserCheckinsView(projectId: detail.id),
          _ProgressTab(detail: detail),
        ],
      ),
    );
  }
}

/// Navigates to the check-in wizard, passing the project's taskType catalog
/// as `extra` so the wizard can show the picker.
void _openCheckin(BuildContext context, ProjectDetail detail) {
  context.pushNamed(
    AppRoute.checkin,
    pathParameters: {'projectId': detail.id},
    queryParameters: {
      'projectName': detail.name,
      'manualLocation': detail.manualLocation.toString(),
    },
    extra: detail.taskTypes,
  );
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({
    required this.detail,
    this.checkinButtonKey,
    this.onCheckinButtonVisibilityChanged,
  });

  final ProjectDetail detail;

  /// Attached to the inline "Agregar un check-in" button so the parent can
  /// tell whether it's on screen. Null in the unsubscribed layout (no button).
  final GlobalKey? checkinButtonKey;
  final ValueChanged<bool>? onCheckinButtonVisibilityChanged;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  @override
  void initState() {
    super.initState();
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(_OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (widget.onCheckinButtonVisibilityChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisibility());
  }

  /// Reports whether the inline check-in button currently intersects the
  /// viewport, using its render box position relative to the screen.
  void _reportVisibility() {
    final callback = widget.onCheckinButtonVisibilityChanged;
    final ctx = widget.checkinButtonKey?.currentContext;
    if (callback == null) return;
    if (ctx == null) {
      callback(false);
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      callback(false);
      return;
    }
    final screenHeight = MediaQuery.sizeOf(context).height;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    callback(bottom > 0 && top < screenHeight);
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final subscribed = detail.isSubscribed;

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _reportVisibility();
        return false;
      },
      child: ListView(
      padding: const EdgeInsets.only(bottom: 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
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
                  // Map is now the hero of the overview (cover image removed),
                  // so give it a big slice of the viewport instead of the
                  // old fixed 280.
                  height: (MediaQuery.sizeOf(context).height * 0.55)
                      .clamp(320.0, 560.0),
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
                LinkifiedText(
                  text: detail.description,
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
                  key: widget.checkinButtonKey,
                  icon: Icons.post_add,
                  label: t.project_add_checkin,
                  filled: true,
                  // Pass the project's taskType catalog as `extra` so the
                  // check-in screen can show the chip picker. No taskType
                  // query param — the user picks one on the next screen.
                  onPressed: () => _openCheckin(context, detail),
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
      ),
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
        try {
          await ref.read(refreshProjectDetailProvider)(detail.id);
        } catch (_) {/* surfaced as AsyncError elsewhere */}
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
      data: (cached) {
        final userId = switch (auth) {
          AuthStateAuthenticated(:final user) => user.id,
          _ => null,
        };
        if (userId == null) return null;
        return cached.value.entryForUser(userId)?.rank;
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
    super.key,
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
  // Graph-first: the dependency tree tells the "how do I get there" story
  // better than a flat grid. Falls back to the grid automatically when the
  // catalog has no edges (the graph would be an empty canvas).
  bool _showGraph = true;

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
                // Compact look is fine, but keep the default (padded) tap
                // target so the toggle stays finger-friendly.
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
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
                onBadgeTap: (b) => _showBadgeDetails(context, b),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared badge detail sheet used from both the grid and the graph. A big
/// hero medium (with the earned glow), the name, a status pill, the
/// description, and the prerequisite chips — everything the user needs to
/// know "what is this and how do I get it" in one clear, generous card.
void _showBadgeDetails(BuildContext context, ProjectBadge badge) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final t = AppLocalizations.of(sheetCtx)!;
      final earned = badge.earned;
      final look = BadgeStatusLook.of(badge, theme, t);
      // The hero disc lights up for a badge you hold *or* one that's slipping
      // away, so the sheet opens with the same urgency the grid promised.
      final lit = earned || look.urgent;
      final color = lit ? look.color : theme.colorScheme.outline;

      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero medium: a 140px disc with the same earned gradient +
              // glow the grid tiles use, so earned badges feel rewarding.
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: lit
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.22),
                            color.withValues(alpha: 0.06),
                          ],
                        )
                      : null,
                  color: lit ? null : color.withValues(alpha: 0.06),
                  border: Border.all(
                    color: color.withValues(alpha: lit ? 0.5 : 0.2),
                    width: lit ? 2 : 1,
                  ),
                  boxShadow: lit
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.28),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: BadgeFadeEffect(
                  availability: badge.availability,
                  child: _BadgeMedia(
                    key: ValueKey(badge.imageUrl),
                    imageUrl: badge.imageUrl,
                    earned: earned,
                    color: color,
                    size: 108,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                badge.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              // Status pill. Carries the live countdown when the badge is
              // fading, so the sheet is where you go to find out exactly how
              // much time is left.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: look.urgent
                      ? look.color.withValues(alpha: 0.16)
                      : earned
                          ? theme.colorScheme.tertiaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: look.urgent
                      ? Border.all(color: look.color.withValues(alpha: 0.5))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      look.icon,
                      size: 16,
                      color: look.urgent
                          ? look.color
                          : earned
                              ? theme.colorScheme.onTertiaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        look.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: look.urgent
                              ? look.color
                              : earned
                                  ? theme.colorScheme.onTertiaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _BadgeFadingNotice(badge: badge, look: look),
              if (badge.description != null &&
                  badge.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  badge.description!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              _BadgeRequirements(badge: badge),
              if (badge.previousBadges.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  t.badge_requires.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final p in badge.previousBadges)
                      Chip(
                        label: Text(p),
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.arrow_upward, size: 14),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// The fading story, spelled out under the status pill.
///
/// Renders nothing for an ordinary badge — the vast majority — so the sheet
/// only grows when there's genuinely something at stake. When a badge is
/// fading this is the nudge ("you can still get it, after this you can't")
/// plus whatever motive the admin wrote. When it's gone it either
/// congratulates you for making it in time or tells you plainly that the
/// chance has passed.
class _BadgeFadingNotice extends StatelessWidget {
  const _BadgeFadingNotice({required this.badge, required this.look});

  final ProjectBadge badge;
  final BadgeStatusLook look;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final fading = badge.availability == BadgeAvailability.fading;
    final expired = badge.availability == BadgeAvailability.expired;
    if (!fading && !expired) return const SizedBox.shrink();

    final headline = fading
        ? (badge.earned
            ? t.badge_fading_earned_hint
            : t.badge_fading_call_to_action)
        : badge.earned
            ? t.badge_expired_kept
            : t.badge_expired_hint;
    final tone = fading ? look.color : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          Text(
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tone,
              fontWeight: fading ? FontWeight.w600 : FontWeight.w400,
              height: 1.35,
            ),
          ),
          // The admin's motive, kept visually quieter than the call to action:
          // it explains, it doesn't push.
          if (badge.fadeReason != null && badge.fadeReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.badge_fade_reason.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.fadeReason!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "How to earn it" card: turns the backend BadgeTemplate rule into a plain
/// checklist — how many check-ins, whether they must solve a task, and any
/// task-type / area / time-interval restriction. Renders nothing when the
/// rule wasn't sent (e.g. a legacy user-overlay badge with no catalog match).
class _BadgeRequirements extends StatelessWidget {
  const _BadgeRequirements({required this.badge});
  final ProjectBadge badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    final rows = <(IconData, String)>[
      if (badge.checkinsAmount > 0)
        (
          Icons.photo_camera_outlined,
          t.badge_req_checkins(badge.checkinsAmount),
        ),
      if (badge.mustContribute)
        (Icons.task_alt, t.badge_req_contribute),
      if (badge.hasTaskType)
        (Icons.category_outlined, t.badge_req_task_type(badge.taskType!)),
      if (badge.hasArea)
        (Icons.place_outlined, t.badge_req_area(badge.areaId!)),
      if (badge.hasTimeInterval)
        (Icons.schedule, t.badge_req_interval(badge.timeIntervalId!)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.badge_how_to_earn.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final (icon, label) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
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
    final t = AppLocalizations.of(context)!;
    final earned = badge.earned;
    final look = BadgeStatusLook.of(badge, theme, t);
    // A fading badge borrows the "won" treatment — gradient, glow, thicker
    // border — but in amber. Same visual weight as an earned one, opposite
    // meaning: this one pops because it's about to be gone, not because you
    // have it. A flat tile would never make anyone hurry.
    final lit = earned || look.urgent;
    final color = look.urgent ? look.color : (earned ? look.color : theme.colorScheme.outline);

    return InkWell(
      onTap: () => _showBadgeDetails(context, badge),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: lit
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.05),
                  ],
                )
              : null,
          color: lit ? null : color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: lit ? 0.5 : 0.15),
            width: lit ? 1.5 : 1,
          ),
          boxShadow: lit
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: look.urgent ? 0.32 : 0.2),
                    blurRadius: look.urgent ? 14 : 10,
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
                      return BadgeFadeEffect(
                        availability: badge.availability,
                        child: _BadgeMedia(
                          key: ValueKey(badge.imageUrl),
                          imageUrl: badge.imageUrl,
                          earned: earned,
                          color: color,
                          size: constraints.biggest.shortestSide,
                        ),
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
                    color: lit
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    // A badge nobody can earn any more is spent, not merely
                    // locked — the strike-through says so without a word.
                    decoration:
                        badge.availability == BadgeAvailability.expired &&
                                !earned
                            ? TextDecoration.lineThrough
                            : null,
                  ),
                ),
              ],
            ),
            // One corner marker, three meanings: earned, ticking down, or
            // gone. The countdown rides along so the grid answers "how long
            // do I have?" without a tap.
            if (earned || badge.availability != BadgeAvailability.active)
              Positioned(
                top: -2,
                right: -2,
                child: BadgeStatusChip(
                  look: look,
                  // A bare tick reads better than `check_circle` inside an
                  // already-circular chip this small.
                  iconOverride:
                      earned && !look.urgent ? Icons.check : null,
                ),
              ),
          ],
        ),
      ),
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

    return ListTile(
      tileColor: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
