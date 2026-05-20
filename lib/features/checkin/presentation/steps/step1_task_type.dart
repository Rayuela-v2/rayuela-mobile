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
    final options = state.availableTaskTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WizardCompanionGuide(
          text: "¡Hola! ¿Qué tipo de tarea querés registrar hoy?",
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(width: 12, height: 2, color: const Color(0xFFC97B2E)),
              const SizedBox(width: 8),
              Text(
                "TIPO DE TAREA",
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
                  child: const Text("Siguiente →", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
