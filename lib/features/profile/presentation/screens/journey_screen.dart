import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../widgets/profile_stats_section.dart';

/// "Your journey" — the aggregated numbers, pushed from the profile so the
/// profile itself stays about editing who you are.
class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.profile_stats_title)),
      body: switch (authState) {
        AuthStateAuthenticated(:final user) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ProfileStatsSection(user: user),
            ),
          ),
        // The router redirects unauthenticated users away; this only shows
        // during the frame where logout is in flight.
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
