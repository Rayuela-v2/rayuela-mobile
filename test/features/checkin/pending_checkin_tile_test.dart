import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_entry.dart';
import 'package:rayuela_mobile/features/checkin/presentation/widgets/pending_checkin_tile.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

OutboxEntry _entry({
  OutboxStatus status = OutboxStatus.pending,
  int attemptCount = 0,
  String? lastErrorMessage,
}) {
  final now = DateTime.utc(2026, 5, 1, 12);
  return OutboxEntry(
    id: 'id-1',
    userId: 'u1',
    projectId: 'p1',
    taskType: 'observation',
    latitude: '-34.6',
    longitude: '-58.4',
    datetime: now,
    clientCapturedAt: now,
    images: const [],
    status: status,
    attemptCount: attemptCount,
    lastErrorMessage: lastErrorMessage,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders the Pending pill for status=pending', (tester) async {
    await tester.pumpWidget(_wrap(
      PendingCheckinTile(entry: _entry(), dense: true),
    ));
    await tester.pump();

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('observation'), findsOneWidget);
  });

  testWidgets('shows attempt counter when attemptCount > 0', (tester) async {
    await tester.pumpWidget(_wrap(
      PendingCheckinTile(
        entry: _entry(status: OutboxStatus.failed, attemptCount: 3),
        dense: true,
      ),
    ));
    await tester.pump();

    expect(find.textContaining('Attempt'), findsOneWidget);
    expect(find.text('Attempt #3'), findsOneWidget);
  });

  testWidgets('exposes Retry / Discard buttons when callbacks are provided',
      (tester) async {
    var retried = false;
    var discarded = false;

    await tester.pumpWidget(_wrap(
      PendingCheckinTile(
        entry: _entry(status: OutboxStatus.dead),
        onRetry: () => retried = true,
        onDiscard: () => discarded = true,
        dense: true,
      ),
    ));
    await tester.pump();

    expect(find.text('Retry now'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    await tester.tap(find.text('Retry now'));
    await tester.tap(find.text('Discard'));
    expect(retried, isTrue);
    expect(discarded, isTrue);
  });

  testWidgets('renders the lastErrorMessage chip when present',
      (tester) async {
    await tester.pumpWidget(_wrap(
      PendingCheckinTile(
        entry: _entry(
          status: OutboxStatus.failed,
          attemptCount: 1,
          lastErrorMessage: 'Server unavailable',
        ),
        dense: true,
      ),
    ));
    await tester.pump();

    expect(find.text('Server unavailable'), findsOneWidget);
  });
}
