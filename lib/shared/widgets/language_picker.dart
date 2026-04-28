import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/locale_controller.dart';
import '../../l10n/app_localizations.dart';

/// Round AppBar action that opens a modal letting the user pick the app's
/// language at runtime. The choice is persisted via [LocaleController].
class LanguagePickerButton extends ConsumerWidget {
  const LanguagePickerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: t.language_picker_tooltip,
      icon: const Icon(Icons.translate),
      onPressed: () => showLanguagePickerDialog(context, ref),
    );
  }
}

/// Opens the language picker as a Material dialog. Returns the chosen
/// locale (or `null` if the user dismissed without changing).
Future<Locale?> showLanguagePickerDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final t = AppLocalizations.of(context)!;
  final current = ref.read(localeControllerProvider);
  final picked = await showDialog<String?>(
    context: context,
    builder: (ctx) => _LanguagePickerDialog(
      currentLocale: current,
    ),
  );
  if (picked == null) return null;

  Locale? newLocale;
  if (picked.isEmpty) {
    await ref.read(localeControllerProvider.notifier).setLocale(null);
  } else {
    newLocale = Locale(picked);
    await ref.read(localeControllerProvider.notifier).setLocale(newLocale);
  }
  
  if (!context.mounted) return newLocale;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(t.language_picker_saved)),
  );
  return newLocale;
}

class _LanguagePickerDialog extends StatelessWidget {
  const _LanguagePickerDialog({required this.currentLocale});

  /// `null` = "follow the system" (the default after a fresh install).
  final Locale? currentLocale;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final selected = currentLocale?.languageCode ?? '';
    return AlertDialog(
      title: Text(t.language_picker_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.language_picker_subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          // "Follow system" — clears the override.
          RadioListTile<String>(
            value: '',
            groupValue: selected,
            title: Text(t.language_system),
            onChanged: (_) => Navigator.of(context).pop(''),
          ),
          for (final locale in AppLocalizations.supportedLocales)
            RadioListTile<String>(
              value: locale.languageCode,
              groupValue: selected,
              title: Text(_labelFor(locale.languageCode, t)),
              onChanged: (_) => Navigator.of(context).pop(locale.languageCode),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common_cancel),
        ),
      ],
    );
  }

  String _labelFor(String code, AppLocalizations t) {
    switch (code) {
      case 'en':
        return t.language_english;
      case 'es':
        return t.language_spanish;
      case 'pt':
        return t.language_portuguese;
      default:
        return code;
    }
  }
}
