import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../dashboard/domain/entities/project_summary.dart';
import '../../../dashboard/presentation/providers/projects_providers.dart';
import '../providers/profile_providers.dart';

/// "Your journey" panel: totals up top, then one row per project.
///
/// Two sources on purpose — points/badges/projects come from the
/// offline-cached projects list so the panel always renders, while the
/// mission counts come from the network and fall back to a dash.
class ProfileStatsSection extends ConsumerWidget {
  const ProfileStatsSection({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final stats = ref.watch(profileStatsProvider);
    final projectsAsync = ref.watch(subscribedProjectsProvider);

    // Same filter the dashboard uses: paused projects stay hidden.
    final projects = projectsAsync.valueOrNull?.value
            .where((p) => p.available)
            .toList(growable: false) ??
        const <ProjectSummary>[];
    final points = projects.fold<int>(0, (sum, p) => sum + p.userPoints);
    final badges = projects.fold<int>(0, (sum, p) => sum + p.userBadgesCount);

    // A dash while offline/loading beats a misleading zero.
    final missions = stats.when(
      data: (s) => '${s.totalCheckins}',
      loading: () => '—',
      error: (_, __) => '—',
    );
    final streak = stats.valueOrNull?.streakDays ?? 0;

    // No heading here — the screen's AppBar already carries the title.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatTile(
              icon: Icons.flag_outlined,
              value: missions,
              label: t.profile_stats_missions,
            ),
            _StatTile(
              icon: Icons.star_outline,
              value: '$points',
              label: t.profile_stats_points,
            ),
            _StatTile(
              icon: Icons.workspace_premium_outlined,
              value: '$badges',
              label: t.profile_stats_badges,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (streak > 0)
              _InfoChip(
                icon: Icons.local_fire_department_outlined,
                label: t.profile_stats_streak(streak),
              ),
            if (user.createdAt != null)
              _InfoChip(
                icon: Icons.hourglass_bottom_outlined,
                label: t.profile_since(_monthYear(context, user.createdAt!)),
              ),
          ],
        ),
        if (projects.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(t.profile_stats_by_project, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final project in projects)
            _ProjectRow(
              project: project,
              missions: stats.valueOrNull?.checkinsFor(project.id),
            ),
        ],
      ],
    );
  }

  String _monthYear(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMM(locale).format(date.toLocal());
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.missions});

  final ProjectSummary project;

  /// Null while the stats call is in flight or failed.
  final int? missions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final parts = [
      t.profile_stats_points_short(project.userPoints),
      t.leaderboard_badges(project.userBadgesCount),
      if (missions != null) t.badge_req_checkins(missions!),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}
