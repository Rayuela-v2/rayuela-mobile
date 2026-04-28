import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/locale/locale_controller.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class RayuelaApp extends ConsumerWidget {
  const RayuelaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // null → fall back to the system locale (the Flutter default). The
    // language picker on the dashboard writes through this controller and
    // persists the choice via SharedPreferences.
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
