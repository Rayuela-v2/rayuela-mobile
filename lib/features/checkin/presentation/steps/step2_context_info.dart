import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/checkin_submission_outcome.dart';
import '../providers/checkin_wizard_controller.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/wizard/location_summary_card.dart';
import '../widgets/wizard/photo_thumb.dart';
import '../widgets/wizard/wizard_companion_guide.dart';
import '../widgets/wizard/wizard_step_scaffold.dart';

class Step2ContextInfo extends ConsumerWidget {
  const Step2ContextInfo({
    super.key,
    required this.args,
    required this.onSubmitted,
  });

  final CheckinWizardArgs args;
  final void Function(CheckinSubmissionOutcome?) onSubmitted;

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

    final isCustomDate = state.customDateTime != null;
    final DateTime activeDateTime = state.customDateTime ?? DateTime.now();
    final now = DateTime.now();
    final localActive = activeDateTime.toLocal();
    final isToday = localActive.year == now.year &&
        localActive.month == now.month &&
        localActive.day == now.day;
    final formattedDateTime = isToday
        ? "${l10n.wizard_date_today}, ${DateFormat.jm().format(localActive)}"
        : DateFormat.yMMMd().add_jm().format(localActive);
    final localError = _localizeError(context, state.error);
    final canSubmit = effectiveLatLng != null && !state.isSubmitting;

    return WizardStepScaffold(
      content: [
        WizardCompanionGuide(
          text: l10n.wizard_step2_guide_confirmation,
        ),

        // SECTION 1: COORDENADAS
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
        const SizedBox(height: 12),
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
        if (effectiveLatLng != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FlutterMap(
                  key: ValueKey(effectiveLatLng),
                  options: MapOptions(
                    initialCenter: effectiveLatLng,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none, // Read-only informative map
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rayuela.mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 36,
                          height: 36,
                          point: effectiveLatLng,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF27AE60),
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // SECTION 2: FECHA Y HORA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(width: 12, height: 2, color: const Color(0xFFC97B2E)),
              const SizedBox(width: 8),
              Text(
                l10n.wizard_step4_title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFF3A2810).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Icon(
                  isCustomDate ? Icons.edit_calendar : Icons.access_time,
                  color: const Color(0xFFC97B2E),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCustomDate
                            ? l10n.wizard_step4_subtitle_custom
                            : l10n.wizard_step4_subtitle_current,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        formattedDateTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EDD6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF3A2810)),
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final initialDate = activeDateTime.isAfter(now) ? now : activeDateTime;
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(2000),
                      lastDate: now,
                    );
                    if (selectedDate == null) return;

                    if (!context.mounted) return;

                    final selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(activeDateTime),
                    );
                    if (selectedTime == null) return;

                    final finalDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    notifier.setCustomDateTime(finalDateTime);
                  },
                ),
              ],
            ),
          ),
        ),
        if (isCustomDate) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextButton.icon(
              onPressed: notifier.clearCustomDateTime,
              icon: const Icon(Icons.restore, size: 16, color: Color(0xFFC97B2E)),
              label: Text(
                l10n.wizard_step4_restore,
                style: const TextStyle(
                  color: Color(0xFFC97B2E),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // SECTION 3: EVIDENCIA · FOTOS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Container(width: 12, height: 2, color: const Color(0xFFC97B2E)),
              const SizedBox(width: 8),
              Text(
                "${l10n.wizard_step2_title} · ${state.images.length} ${state.images.length == 1 ? 'FOTO' : 'FOTOS'}",
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFF3A2810).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              if (state.images.length < 3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _AddActionButton(
                        onPressed: () => notifier.pickImage(ImageSource.camera),
                        icon: Icons.photo_camera,
                        label: l10n.wizard_step2_cam,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AddActionButton(
                        onPressed: () => notifier.pickImage(ImageSource.gallery),
                        icon: Icons.photo_library,
                        label: l10n.wizard_step2_gal,
                      ),
                    ),
                  ],
                ),
              if (state.images.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ...state.images.asMap().entries.map((entry) {
                      return PhotoThumb(
                        image: entry.value,
                        onRemove: () => notifier.removeImage(entry.key),
                      );
                    }),
                  ],
                ),
              ],
            ],
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
                onPressed: canSubmit
                    ? () async {
                        final outcome = await notifier.submit();
                        if (outcome != null) {
                          onSubmitted(outcome);
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4DBA87),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        l10n.wizard_confirm,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

class _AddActionButton extends StatelessWidget {
  const _AddActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF37474F),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black12),
        ),
      ),
    );
  }
}
