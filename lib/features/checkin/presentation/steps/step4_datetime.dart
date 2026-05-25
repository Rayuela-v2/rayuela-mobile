import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/checkin_submission_outcome.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/checkin_wizard_controller.dart';
import '../widgets/wizard/wizard_companion_guide.dart';

class Step4DateTime extends ConsumerWidget {
  const Step4DateTime({
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
    final isCustom = state.customDateTime != null;
    final DateTime activeDateTime = state.customDateTime ?? DateTime.now();

    final formatted = DateFormat.yMMMd().add_jm().format(activeDateTime.toLocal());
    final companionText = isCustom
        ? l10n.wizard_step4_guide_custom
        : l10n.wizard_step4_guide_current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardCompanionGuide(
          text: companionText,
        ),
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
        const SizedBox(height: 16),
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
                  isCustom ? Icons.edit_calendar : Icons.access_time,
                  color: const Color(0xFFC97B2E),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCustom ? l10n.wizard_step4_subtitle_custom : l10n.wizard_step4_subtitle_current,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        formatted,
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
        if (isCustom) ...[
          const SizedBox(height: 12),
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
        const Spacer(),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              _localizeError(context, state.error),
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
                  onPressed: !state.isSubmitting
                      ? () async {
                          final result = await notifier.submit();
                          if (result != null) {
                            onSubmitted(result);
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8973A),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bolt, size: 18),
                            const SizedBox(width: 8),
                            Text(l10n.wizard_submit, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  String _localizeError(BuildContext context, String? error) {
    if (error == null) return '';
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      'wizard_error_select_type' => l10n.wizard_error_select_type,
      'wizard_error_waiting_location' => l10n.wizard_error_waiting_location,
      'wizard_error_future_date' => l10n.wizard_error_future_date,
      _ => error,
    };
  }
}
