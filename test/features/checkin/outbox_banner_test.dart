import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rayuela_mobile/core/router/routes.dart';
import 'package:rayuela_mobile/core/sync/outbox/sync_status.dart';
import 'package:rayuela_mobile/features/checkin/presentation/providers/outbox_providers.dart';
import 'package:rayuela_mobile/features/checkin/presentation/widgets/outbox_badge.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

/// Builds a minimal MaterialApp with a single route so the inner
/// `context.pushNamed(AppRoute.pendingData)` taps don't blow up.
Widget _hostWith({
  required Widget child,
  required List<Override> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(
        path: AppPath.pendingData,
        name: AppRoute.pendingData,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Pending data screen'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('OutboxBanner is hidden when count == 0', (tester) async {
    await tester.pumpWidget(_hostWith(
      child: const OutboxBanner(),
      overrides: [
        pendingCheckinCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('OutboxBanner shows the singular copy for count == 1',
      (tester) async {
    await tester.pumpWidget(_hostWith(
      child: const OutboxBanner(),
      overrides: [
        pendingCheckinCountProvider.overrideWith((ref) => Stream.value(1)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 check-in waiting to sync'), findsOneWidget);
  });

  testWidgets('OutboxBanner shows the plural copy with the count',
      (tester) async {
    await tester.pumpWidget(_hostWith(
      child: const OutboxBanner(),
      overrides: [
        pendingCheckinCountProvider.overrideWith((ref) => Stream.value(4)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('4 check-ins waiting to sync'), findsOneWidget);
  });

  testWidgets('SyncStatusBadge renders nothing for SyncStatus.idle',
      (tester) async {
    await tester.pumpWidget(_hostWith(
      child: const SyncStatusBadge(),
      overrides: [
        syncStatusProvider.overrideWith((ref) => Stream.value(SyncStatus.idle)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('SyncStatusBadge surfaces an icon button when offline',
      (tester) async {
    await tester.pumpWidget(_hostWith(
      child: const SyncStatusBadge(),
      overrides: [
        syncStatusProvider
            .overrideWith((ref) => Stream.value(SyncStatus.offline)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });
}
