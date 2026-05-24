import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/checkin_wizard_controller.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/wizard/location_summary_card.dart';
import '../widgets/wizard/wizard_companion_guide.dart';

class Step3Location extends ConsumerWidget {
  const Step3Location({
    super.key,
    required this.args,
  });

  final CheckinWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinWizardProvider(args));
    final notifier = ref.read(checkinWizardProvider(args).notifier);
    final theme = Theme.of(context);

    // Derived effective LatLng
    LatLng? effectiveLatLng;
    if (state.manualLatLng != null) {
      effectiveLatLng = state.manualLatLng;
    } else if (state.position != null) {
      effectiveLatLng = LatLng(state.position!.latitude, state.position!.longitude);
    }

    final canSubmit = effectiveLatLng != null && !state.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WizardCompanionGuide(
          text: "Estamos usando tu ubicación actual. ¿Querés modificarla?",
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(width: 12, height: 2, color: const Color(0xFFC97B2E)),
              const SizedBox(width: 8),
              Text(
                "COORDENADAS",
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LocationSummaryCard(
            position: state.position,
            manualLatLng: state.manualLatLng,
            resolving: state.resolvingLocation,
            errorMessage: state.error,
            onRetry: notifier.initLocation,
            onPickOnMap: () async {
              final picked = await LocationPickerSheet.show(context, initial: effectiveLatLng);
              if (picked != null) {
                notifier.setManualLocation(picked);
              }
            },
            onClearManual: notifier.clearManualLocation,
          ),
        ),
        const Spacer(),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
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
                  onPressed: canSubmit ? notifier.nextStep : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4DBA87),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Siguiente →", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
