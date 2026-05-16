import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/checkin_result.dart';
import '../../domain/entities/checkin_submission_outcome.dart';

/// Two-faced screen reached after the volunteer hits "Submit":
///
///   * **Accepted** — backend processed the check-in synchronously.
///     We celebrate the points/badges with the elastic hero animation.
///   * **Queued** — the device was offline (or had a non-empty queue).
///     We show a "we'll send it as soon as we have signal" panel
///     instead of the reward to set the right expectation. The drainer
///     will fire whenever connectivity comes back.
class CheckinResultScreen extends StatefulWidget {
  const CheckinResultScreen({
    super.key,
    required this.outcome,
    required this.projectId,
  });

  final CheckinSubmissionOutcome outcome;
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
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
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
          child: switch (widget.outcome) {
            CheckinSubmissionAccepted(:final result) => _AcceptedView(
                result: result,
                animation: _controller,
                projectId: widget.projectId,
              ),
            CheckinSubmissionQueued(:final outboxId, :final queuedAt) =>
              _QueuedView(
                outboxId: outboxId,
                queuedAt: queuedAt,
                projectId: widget.projectId,
              ),
            // Should not happen — Rejected outcomes never navigate here.
            CheckinSubmissionRejected() => _QueuedView(
                outboxId: '',
                queuedAt: DateTime.now(),
                projectId: widget.projectId,
              ),
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Accepted view — original celebratory layout
// -----------------------------------------------------------------------------

class _AcceptedView extends StatelessWidget {
  const _AcceptedView({
    required this.result,
    required this.animation,
    required this.projectId,
  });

  final CheckinResult result;
  final AnimationController animation;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final hasBadges = result.newBadges.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
          child: _PointsHero(points: result.pointsAwarded),
        ),
        if (result.contributesTo != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              t.checkin_result_contributed_to(result.contributesTo!.name),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (result.message != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(result.message!, style: theme.textTheme.bodyMedium),
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
              itemCount: result.newBadges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _BadgeTile(badge: result.newBadges[i]),
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(height: 16),
        _BackButtons(projectId: projectId),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Queued view — informational, no reward
// -----------------------------------------------------------------------------

class _QueuedView extends StatelessWidget {
  const _QueuedView({
    required this.outboxId,
    required this.queuedAt,
    required this.projectId,
  });

  final String outboxId;
  final DateTime queuedAt;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final formatter = DateFormat.Hm(Localizations.localeOf(context).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_queue_outlined,
                size: 48,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(height: 8),
              Text(
                t.checkin_result_queued_title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t.checkin_result_queued_subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.checkin_result_queued_at(formatter.format(queuedAt)),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _BackButtons(projectId: projectId),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Shared bits
// -----------------------------------------------------------------------------

class _BackButtons extends StatelessWidget {
  const _BackButtons({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.goNamed(
                AppRoute.projectDetail,
                pathParameters: {'projectId': projectId},
              );
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(t.checkin_back_to_project),
        ),
      ],
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
              color: theme.colorScheme.primary, size: 32,),
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
