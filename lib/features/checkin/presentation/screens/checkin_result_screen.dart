import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/checkin_result.dart';
import '../../domain/entities/checkin_submission_outcome.dart';
import '../providers/checkin_wizard_controller.dart';
import '../widgets/wizard/companion_avatar.dart';
import '../widgets/wizard/companion_bubble.dart';

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
    // Scoped args forced to step 3 (final) for progress bar
    final args = CheckinWizardArgs(projectId: widget.projectId);
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A2F), // dark green background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: const SizedBox.shrink(), // hide back
        title: Text(
          t.checkin_result_ready_title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC97B2E).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC97B2E).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check, size: 12, color: Color(0xFFC97B2E)),
                const SizedBox(width: 4),
                Text(
                  t.checkin_result_complete_badge,
                  style: const TextStyle(color: Color(0xFFC97B2E), fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ForcedProgressBar(args: args),
            // Content scrolls when it doesn't fit; the back button below stays
            // pinned and always reachable.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: switch (widget.outcome) {
                  CheckinSubmissionAccepted(:final result) => _AcceptedView(
                      result: result,
                      animation: _controller,
                    ),
                  CheckinSubmissionQueued(:final outboxId, :final queuedAt) =>
                    _QueuedView(
                      outboxId: outboxId,
                      queuedAt: queuedAt,
                    ),
                  CheckinSubmissionRejected(:final error) => _RejectedView(
                      error: error.message,
                    ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _BackButtons(
                projectId: widget.projectId,
                label: widget.outcome is CheckinSubmissionQueued
                    ? t.common_continue
                    : t.checkin_back_to_project,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForcedProgressBar extends StatelessWidget {
  const _ForcedProgressBar({required this.args});
  final CheckinWizardArgs args;

  @override
  Widget build(BuildContext context) {
    const totalSteps = 4;
    const step = 3; // Forced last step
    const progressColor = Color(0xFFC97B2E);
    final backgroundColor = Colors.white.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isCompleted = index <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                right: index == totalSteps - 1 ? 0 : 6,
              ),
              decoration: BoxDecoration(
                color: isCompleted ? progressColor : backgroundColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AcceptedView extends StatelessWidget {
  const _AcceptedView({
    required this.result,
    required this.animation,
  });

  final CheckinResult result;
  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final contributesTo = result.contributesTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.checkin_result_accepted_heading,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CompanionAvatar(size: 64, ringColor: Colors.transparent),
          ],
        ),
        const SizedBox(height: 16),
        CompanionBubble(
          child: Text(
            contributesTo != null
                ? t.checkin_result_task_completed(contributesTo.name)
                : t.checkin_result_generic_thanks,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3A2810), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        if (result.pointsAwarded > 0) ...[
          const SizedBox(height: 32),
          ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ),
            child: _PointsCircle(points: result.pointsAwarded, label: t.project_stat_points.toUpperCase()),
          ),
          const SizedBox(height: 32),
        ] else
          const SizedBox(height: 32),
        if (result.newBadges.isNotEmpty) ...[
          Text(
            t.checkin_result_new_badges,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: result.newBadges
                .map((badge) => _BadgeCircle(badge: badge))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          t.checkin_result_accepted_done,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          t.checkin_result_accepted_subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

class _QueuedView extends StatelessWidget {
  const _QueuedView({
    required this.outboxId,
    required this.queuedAt,
  });

  final String outboxId;
  final DateTime queuedAt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "¡Colaboración\npendiente!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CompanionAvatar(size: 64, ringColor: Colors.transparent),
          ],
        ),
        const SizedBox(height: 16),
        CompanionBubble(
          child: Text(
            t.checkin_result_queued_subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3A2810), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 40),
        const Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.white24),
      ],
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView({
    required this.error,
  });

  final String error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "¡Algo salió mal!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CompanionAvatar(size: 64, ringColor: Colors.red),
          ],
        ),
        const SizedBox(height: 16),
        CompanionBubble(
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3A2810), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 80, color: Colors.white24),
      ],
    );
  }
}

class _BackButtons extends StatelessWidget {
  const _BackButtons({required this.projectId, this.label});
  final String projectId;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => context.goNamed(
          AppRoute.projectDetail,
          pathParameters: {'projectId': projectId},
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF4DBA87),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Text(label ?? t.checkin_back_to_project),
      ),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const _BadgeCircle({required this.badge});
  final BadgeAward badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF4DBA87), width: 8),
          ),
          child: ClipOval(
            child: (badge.imageUrl != null && badge.imageUrl!.isNotEmpty)
                ? Image.network(
                    badge.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _BadgeFallbackIcon(),
                  )
                : const _BadgeFallbackIcon(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          badge.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _BadgeFallbackIcon extends StatelessWidget {
  const _BadgeFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1E3A2F),
      child: Center(
        child: Icon(Icons.emoji_events_outlined, size: 60, color: Color(0xFF4DBA87)),
      ),
    );
  }
}

class _PointsCircle extends StatelessWidget {
  const _PointsCircle({required this.points, required this.label});
  final int points;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF4DBA87).withValues(alpha: 0.3), width: 8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+$points',
                style: const TextStyle(
                  color: Color(0xFF4DBA87),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF4DBA87), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
