import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_controller.dart';
import '../../l10n/app_localizations.dart';

/// AppBar action that flips between light and dark. Starts from whatever
/// the system is currently showing, then persists the explicit choice.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: AppLocalizations.of(context)!.theme_toggle_tooltip,
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref
          .read(themeControllerProvider.notifier)
          .set(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
