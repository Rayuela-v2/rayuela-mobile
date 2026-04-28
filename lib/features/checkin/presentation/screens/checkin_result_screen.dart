import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/checkin_result.dart';

/// Celebrates a successful check-in: points awarded, new badges, score.
/// Routed to via `context.goNamed(AppRoute.checkinResult, extra: result)`.
class CheckinResultScreen extends StatefulWidget {
  const CheckinResultScreen({
    super.key,
    required this.result,
    required this.projectId,
  });

  final CheckinResult result;
  final String projectId;

  @override
  State<CheckinResultScreen> createState() => _CheckinResultScreenState();
}

class _CheckinResultScreenState extends State<CheckinResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final r = widget.result;
    final hasBadges = r.newBadges.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        // Pop back to the project detail (which is just below us in the
        // stack thanks to pushReplacementNamed from the form). If for some
        // reason the result was reached without a stack to pop, fall back
        // to the dashboard.
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.goNamed(AppRoute.dashboard);
            }
          },
        ),
        title: Text(t.checkin_result_title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.elasticOut,
                ),
                child: _PointsHero(points: r.pointsAwarded),
              ),
              if (r.contributesTo != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    t.checkin_result_contributed_to(r.contributesTo!.name),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (r.message != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    r.message!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (hasBadges) ...[
                Text(
                  t.checkin_result_new_badges,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: r.newBadges.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _BadgeTile(badge: r.newBadges[i]),
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.goNamed(AppRoute.dashboard),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(t.checkin_back_to_dashboard),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  // Pop the result so we land back on the project detail
                  // (the natural place to start another check-in).
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.goNamed(
                      AppRoute.projectDetail,
                      pathParameters: {'projectId': widget.projectId},
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(t.checkin_back_to_project),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.celebration_outlined,
            size: 48,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            t.checkin_result_points_label(points),
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            points == 0
                ? t.checkin_result_recorded
                : t.checkin_result_earned,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});
  final BadgeAward badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined,
              color: theme.colorScheme.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (badge.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    badge.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
