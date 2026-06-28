import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/checkin_wizard_controller.dart';

class WizardProgressBar extends ConsumerWidget {
  const WizardProgressBar({super.key, required this.args});

  final CheckinWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinWizardProvider(args));
    final totalSteps = state.visibleStepCount;
    final currentIndex = state.visibleStepIndex;

    const progressColor = Color(0xFFC97B2E); // amber from design
    final backgroundColor = Colors.white.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isCompleted = index <= currentIndex;
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
