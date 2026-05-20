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

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A2F), // dark green background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: const SizedBox.shrink(), // hide back
        title: const Text(
          "¡LISTO!",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
            child: const Row(
              children: [
                Icon(Icons.check, size: 12, color: Color(0xFFC97B2E)),
                SizedBox(width: 4),
                Text(
                  "Completo",
                  style: TextStyle(color: Color(0xFFC97B2E), fontWeight: FontWeight.bold, fontSize: 10),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  CheckinSubmissionRejected(:final error) => _RejectedView(
                      error: error.message,
                      projectId: widget.projectId,
                    ),
                },
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
    required this.projectId,
  });

  final CheckinResult result;
  final AnimationController animation;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "¡Colaboración\nregistrada!",
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
        const CompanionBubble(
          child: Text(
            "¡Excelente trabajo! Ya sumaste tu colaboración 🎉",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF3A2810), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const Spacer(),
        ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
          child: _PointsCircle(points: result.pointsAwarded),
        ),
        const Spacer(),
        const Text(
          "¡Ya colaboraste!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const Text(
          "Check-in finalizado",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("🔥", style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                "¡Nueva colaboración!",
                style: TextStyle(color: Color(0xFFE8973A), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _BackButtons(projectId: projectId),
        const SizedBox(height: 16),
      ],
    );
  }
}

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
        const CompanionBubble(
          child: Text(
            "¡Buen trabajo! La enviaremos apenas tengas conexión.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF3A2810), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const Spacer(),
        const Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.white24),
        const Spacer(),
        _BackButtons(projectId: projectId, label: t.common_continue),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView({
    required this.error,
    required this.projectId,
  });

  final String error;
  final String projectId;

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
        const Spacer(),
        const Icon(Icons.error_outline, size: 80, color: Colors.white24),
        const Spacer(),
        _BackButtons(projectId: projectId),
        const SizedBox(height: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () => context.goNamed(AppRoute.dashboard),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4DBA87),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Text(label ?? "Seguir explorando →"),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            context.goNamed(
              AppRoute.projectDetail,
              pathParameters: {'projectId': projectId},
            );
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Text(t.checkin_back_to_project),
        ),
      ],
    );
  }
}

class _PointsCircle extends StatelessWidget {
  const _PointsCircle({required this.points});
  final int points;

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
              const Text(
                "PUNTOS",
                style: TextStyle(color: Color(0xFF4DBA87), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
