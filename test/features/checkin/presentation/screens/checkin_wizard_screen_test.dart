import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/error/result.dart';
import 'package:rayuela_mobile/core/router/routes.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_request.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_submission_outcome.dart';
import 'package:rayuela_mobile/features/checkin/domain/repositories/checkins_repository.dart';
import 'package:rayuela_mobile/features/checkin/presentation/providers/checkin_providers.dart';
import 'package:rayuela_mobile/features/checkin/presentation/providers/checkin_wizard_controller.dart';
import 'package:rayuela_mobile/features/checkin/presentation/screens/checkin_wizard_screen.dart';
import 'package:rayuela_mobile/features/checkin/presentation/services/location_service.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

class _MockCheckinsRepository extends Mock implements CheckinsRepository {}

class _MockLocationService extends Mock implements LocationService {}

class _FakeCheckinRequest extends Fake implements CheckinRequest {}

Widget _hostWith({
  required Widget child,
  required List<Override> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(
        path: '/checkin-result/:projectId',
        name: AppRoute.checkinResult,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Result Screen'))),
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
  setUpAll(() {
    registerFallbackValue(_FakeCheckinRequest());
  });

  late _MockCheckinsRepository repository;
  late _MockLocationService locationService;
  late Position mockPosition;

  setUp(() {
    repository = _MockCheckinsRepository();
    locationService = _MockLocationService();
    mockPosition = Position(
      latitude: -34.6037,
      longitude: -58.3816,
      timestamp: DateTime.utc(2026, 5, 16),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    when(() => locationService.currentPosition())
        .thenAnswer((_) async => mockPosition);
  });

  testWidgets('CheckinWizardScreen full step flow integration', (tester) async {
    const args = CheckinWizardArgs(
      projectId: 'p1',
      availableTaskTypes: [
        TaskType(name: 'Clean'),
        TaskType(name: 'Repair'),
      ],
    );

    final outcomeResult = CheckinSubmissionQueued(
      outboxId: 'q1',
      queuedAt: DateTime.utc(2026, 5, 16),
    );

    when(() => repository.submitCheckin(any()))
        .thenAnswer((_) async => Success(outcomeResult));

    await tester.pumpWidget(
      _hostWith(
        child: const CheckinWizardScreen(args: args),
        overrides: [
          checkinsRepositoryProvider.overrideWithValue(repository),
          locationServiceProvider.overrideWithValue(locationService),
        ],
      ),
    );

    // Wait for the widgets and the async location initialization to finish
    await tester.pumpAndSettle();

    // ----------------------------------------------------
    // STEP 1: Select Task Type
    // ----------------------------------------------------
    expect(find.text('MISSION TYPE'), findsOneWidget);
    expect(find.text('Clean'), findsOneWidget);
    expect(find.text('Repair'), findsOneWidget);

    // Click "Clean" task card
    await tester.tap(find.text('Clean'));
    await tester.pumpAndSettle();

    // Click "Next"
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // ----------------------------------------------------
    // STEP 2: Context Information (Coordinates, DateTime, Photos)
    // ----------------------------------------------------
    expect(find.text('COORDINATES'), findsOneWidget);
    expect(find.text('DATE & TIME'), findsOneWidget);
    expect(find.textContaining('EVIDENCE'), findsOneWidget);
    expect(find.text('Using current location'), findsOneWidget);

    // Tap "Confirm" button
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify submission is processed and navigates to the result screen
    verify(() => repository.submitCheckin(any())).called(1);
    expect(find.text('Result Screen'), findsOneWidget);
  });
}
