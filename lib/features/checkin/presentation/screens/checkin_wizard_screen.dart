import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../providers/checkin_wizard_controller.dart';
import '../steps/step1_task_type.dart';
import '../steps/step2_evidence.dart';
import '../steps/step3_location.dart';
import '../steps/step4_datetime.dart';
import '../widgets/wizard/wizard_appbar.dart';
import '../widgets/wizard/wizard_progress_bar.dart';

class CheckinWizardScreen extends ConsumerStatefulWidget {
  const CheckinWizardScreen({
    super.key,
    required this.args,
  });

  final CheckinWizardArgs args;

  @override
  ConsumerState<CheckinWizardScreen> createState() => _CheckinWizardScreenState();
}

class _CheckinWizardScreenState extends ConsumerState<CheckinWizardScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialStep = ref.read(checkinWizardProvider(widget.args)).step;
    _pageController = PageController(initialPage: initialStep);
    
    // Trigger location initialization asynchronously after build to avoid blocking construction/init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkinWizardProvider(widget.args).notifier).initLocation();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinWizardProvider(widget.args));
    
    // Sync PageController with state changes
    ref.listen(checkinWizardProvider(widget.args).select((s) => s.step), (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    return PopScope(
      canPop: state.step == state.firstStep,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(checkinWizardProvider(widget.args).notifier).previousStep();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E3A2F), // dark green top
        appBar: WizardAppBar(args: widget.args),
        body: Column(
          children: [
            WizardProgressBar(args: widget.args),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F3E6), // cream background for content
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Step1TaskType(args: widget.args),
                    Step2Evidence(args: widget.args),
                    Step3Location(args: widget.args),
                    Step4DateTime(
                      args: widget.args,
                      onSubmitted: (outcome) {
                        context.pushReplacementNamed(
                          AppRoute.checkinResult,
                          pathParameters: {'projectId': widget.args.projectId},
                          extra: outcome,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
