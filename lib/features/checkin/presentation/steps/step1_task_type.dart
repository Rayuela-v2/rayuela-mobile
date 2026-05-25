import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/checkin_wizard_controller.dart';
import '../widgets/wizard/task_type_card.dart';
import '../widgets/wizard/wizard_companion_guide.dart';

class Step1TaskType extends ConsumerStatefulWidget {
  const Step1TaskType({super.key, required this.args});

  final CheckinWizardArgs args;

  @override
  ConsumerState<Step1TaskType> createState() => _Step1TaskTypeState();
}

class _Step1TaskTypeState extends ConsumerState<Step1TaskType> {
  late final PageController _carouselController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(checkinWizardProvider(widget.args));
    int initialPage = 0;
    if (state.taskType != null) {
      initialPage = state.availableTaskTypes.indexOf(state.taskType!);
      if (initialPage == -1) initialPage = 0;
    }
    _carouselController = PageController(
      viewportFraction: 0.45,
      initialPage: initialPage,
    );
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinWizardProvider(widget.args));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final options = state.availableTaskTypes;

    if (options.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  l10n.wizard_step1_empty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.wizard_step1_empty_back),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardCompanionGuide(
          text: l10n.wizard_step1_guide,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(width: 12, height: 2, color: const Color(0xFFC97B2E)),
              const SizedBox(width: 8),
              Text(
                l10n.wizard_step1_title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFF3A2810).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _carouselController,
            itemCount: options.length,
            onPageChanged: (index) {
               ref.read(checkinWizardProvider(widget.args).notifier).setTaskType(options[index]);
            },
            itemBuilder: (context, index) {
              final type = options[index];
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 110,
                    child: TaskTypeCard(
                      taskType: type,
                      isSelected: state.taskType == type,
                      onTap: () {
                        _carouselController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                        ref.read(checkinWizardProvider(widget.args).notifier).setTaskType(type);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "← deslizá →",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.black38),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E3A2F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.taskType != null
                      ? () => ref.read(checkinWizardProvider(widget.args).notifier).nextStep()
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4DBA87),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.wizard_next, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
