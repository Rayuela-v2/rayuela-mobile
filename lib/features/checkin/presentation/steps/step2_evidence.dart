import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/checkin_wizard_controller.dart';
import '../widgets/wizard/photo_thumb.dart';
import '../widgets/wizard/wizard_companion_guide.dart';
import '../widgets/wizard/wizard_step_scaffold.dart';

class Step2Evidence extends ConsumerWidget {
  const Step2Evidence({super.key, required this.args});

  final CheckinWizardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinWizardProvider(args));
    final notifier = ref.read(checkinWizardProvider(args).notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return WizardStepScaffold(
      content: [
        WizardCompanionGuide(
          text: l10n.wizard_step2_guide,
        ),
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
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
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
              if (state.images.length < 3) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AddActionButton(
                      onPressed: () => notifier.pickImage(ImageSource.camera),
                      icon: Icons.photo_camera,
                      label: l10n.wizard_step2_cam,
                    ),
                    const SizedBox(width: 24),
                    _AddActionButton(
                      onPressed: () => notifier.pickImage(ImageSource.gallery),
                      icon: Icons.photo_library,
                      label: l10n.wizard_step2_gal,
                    ),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: notifier.nextStep,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4DBA87),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.wizard_next, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (state.images.isEmpty)
              TextButton(
                onPressed: notifier.nextStep,
                child: Text(
                  l10n.wizard_step2_skip,
                  style: const TextStyle(
                    color: Color(0xFFF5EDD6),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black12),
        ),
      ),
    );
  }
}
