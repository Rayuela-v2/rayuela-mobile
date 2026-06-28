import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/checkin_wizard_controller.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/wizard/location_summary_card.dart';
import '../widgets/wizard/wizard_companion_guide.dart';
import '../widgets/wizard/wizard_step_scaffold.dart';

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
    final l10n = AppLocalizations.of(context)!;

    // Derived effective LatLng
    LatLng? effectiveLatLng;
    if (state.manualLatLng != null) {
      effectiveLatLng = state.manualLatLng;
    } else if (state.position != null) {
      effectiveLatLng = LatLng(state.position!.latitude, state.position!.longitude);
    }

    final canSubmit = effectiveLatLng != null && !state.isSubmitting;
    final localError = _localizeError(context, state.error);

    return WizardStepScaffold(
      content: [
        WizardCompanionGuide(
          text: l10n.wizard_step3_guide,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(width: 12, height: 2, color: const Color(0xFFC97B2E)),
              const SizedBox(width: 8),
              Text(
                l10n.wizard_step3_title,
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
            errorMessage: localError,
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
      ],
      footer: WizardFooter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (localError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  localError,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red[200]),
                  textAlign: TextAlign.center,
                ),
              ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.wizard_next, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _localizeError(BuildContext context, String? error) {
    if (error == null || error.isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      'wizard_error_select_type' => l10n.wizard_error_select_type,
      'wizard_error_waiting_location' => l10n.wizard_error_waiting_location,
      'wizard_error_future_date' => l10n.wizard_error_future_date,
      _ => error,
    };
  }
}
