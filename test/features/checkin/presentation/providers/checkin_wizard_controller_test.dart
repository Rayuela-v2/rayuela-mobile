import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/error/result.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_request.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_submission_outcome.dart';
import 'package:rayuela_mobile/features/checkin/domain/repositories/checkins_repository.dart';
import 'package:rayuela_mobile/features/checkin/presentation/providers/checkin_wizard_controller.dart';
import 'package:rayuela_mobile/features/checkin/presentation/services/location_service.dart';

class _MockCheckinsRepository extends Mock implements CheckinsRepository {}
class _MockLocationService extends Mock implements LocationService {}
class _FakeCheckinRequest extends Fake implements CheckinRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCheckinRequest());
  });

  late _MockCheckinsRepository repository;
  late _MockLocationService locationService;
  late Position fakePosition;

  setUp(() {
    repository = _MockCheckinsRepository();
    locationService = _MockLocationService();
    fakePosition = Position(
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
        .thenAnswer((_) async => fakePosition);
  });

  CheckinWizardController build({
    String projectId = 'p1',
    String? taskId,
    String? initialTaskType,
    List<TaskType> availableTaskTypes = const [
      TaskType(name: 'obs'),
      TaskType(name: 'pic'),
    ],
  }) {
    return CheckinWizardController(
      repository: repository,
      locationService: locationService,
      projectId: projectId,
      taskId: taskId,
      initialTaskType: initialTaskType,
      availableTaskTypes: availableTaskTypes,
    );
  }

  test('initialization resolves location and sets state', () async {
    final controller = build();
    
    // Explicitly call initLocation since it is no longer called in constructor
    await controller.initLocation();

    expect(controller.state.projectId, 'p1');
    expect(controller.state.position?.latitude, -34.6037);
    expect(controller.state.position?.longitude, -58.3816);
    expect(controller.state.step, 0);
    expect(controller.state.resolvingLocation, false);
  });

  test('nextStep and previousStep navigate steps', () async {
    final controller = build();
    await controller.initLocation();

    expect(controller.state.step, 0);

    controller.nextStep();
    expect(controller.state.step, 1);

    controller.previousStep();
    expect(controller.state.step, 0);

    // Cannot go below step 0
    controller.previousStep();
    expect(controller.state.step, 0);
  });

  test('setTaskType updates task type in state', () async {
    final controller = build();
    await controller.initLocation();

    expect(controller.state.taskType, isNull);

    controller.setTaskType(const TaskType(name: 'obs'));
    expect(controller.state.taskType, const TaskType(name: 'obs'));
  });

  test('preset task type with empty catalog backfills availableTaskTypes',
      () async {
    // Deep-link from the tasks list passes a taskType but no catalog. Step 1
    // must still have a type to show instead of the "no task types" state.
    final controller = build(
      taskId: 't1',
      initialTaskType: 'obs',
      availableTaskTypes: const [],
    );

    expect(controller.state.taskType, const TaskType(name: 'obs'));
    expect(controller.state.availableTaskTypes, [const TaskType(name: 'obs')]);
  });

  test('submit fails if taskType is null', () async {
    final controller = build();
    await controller.initLocation();

    final outcome = await controller.submit();
    expect(outcome, isNull);
    expect(controller.state.error, 'wizard_error_select_type');
  });

  test('submit fails if location is not resolved', () async {
    // Stub location service to throw an exception
    when(() => locationService.currentPosition())
        .thenThrow(const LocationDisabledException());

    final controller = build();
    await controller.initLocation();

    controller.setTaskType(const TaskType(name: 'obs'));

    final outcome = await controller.submit();
    expect(outcome, isNull);
    expect(controller.state.error, 'wizard_error_waiting_location');
  });

  test('successful submit invokes repository with correct payload (excluding notes)', () async {
    final controller = build(taskId: 't1', initialTaskType: 'obs');
    await controller.initLocation();

    final outcomeResult = CheckinSubmissionQueued(
      outboxId: 'q1',
      queuedAt: DateTime.utc(2026, 5, 16),
    );

    when(() => repository.submitCheckin(any()))
        .thenAnswer((_) async => Success(outcomeResult));

    final outcome = await controller.submit();
    expect(outcome, isA<CheckinSubmissionQueued>());
    expect(controller.state.isSubmitting, false);
    expect(controller.state.error, isNull);

    final captured = verify(() => repository.submitCheckin(captureAny())).captured.single as CheckinRequest;
    expect(captured.projectId, 'p1');
    expect(captured.taskId, 't1');
    expect(captured.taskType, 'obs');
    expect(captured.latitude, '-34.6037');
    expect(captured.longitude, '-58.3816');
    expect(captured.imagePaths, isEmpty);
  });

  test('setCustomDateTime and clearCustomDateTime update customDateTime state', () async {
    final controller = build();
    await controller.initLocation();

    expect(controller.state.customDateTime, isNull);

    // Use a past date (May 20, 2026) to avoid the future date restriction
    final targetDateTime = DateTime.utc(2026, 5, 20, 10, 30);
    controller.setCustomDateTime(targetDateTime);
    expect(controller.state.customDateTime, targetDateTime);

    controller.clearCustomDateTime();
    expect(controller.state.customDateTime, isNull);
  });

  test('successful submit with customDateTime uses customDateTime in CheckinRequest', () async {
    final controller = build(taskId: 't1', initialTaskType: 'obs');
    await controller.initLocation();

    // Use a past date (May 20, 2026) to avoid the future date restriction
    final targetDateTime = DateTime.utc(2026, 5, 20, 10, 30);
    controller.setCustomDateTime(targetDateTime);

    final outcomeResult = CheckinSubmissionQueued(
      outboxId: 'q1',
      queuedAt: DateTime.utc(2026, 5, 16),
    );

    when(() => repository.submitCheckin(any()))
        .thenAnswer((_) async => Success(outcomeResult));

    final outcome = await controller.submit();
    expect(outcome, isA<CheckinSubmissionQueued>());

    final captured = verify(() => repository.submitCheckin(captureAny())).captured.single as CheckinRequest;
    expect(captured.datetime, targetDateTime);
  });

  test('initLocation sets error state when location resolution fails', () async {
    // Stub location service to throw a LocationDisabledException
    when(() => locationService.currentPosition())
        .thenThrow(const LocationDisabledException());

    final controller = build();
    await controller.initLocation();

    expect(controller.state.position, isNull);
    expect(controller.state.resolvingLocation, false);
    expect(
      controller.state.error,
      'Location services are turned off. Enable them to check in.',
    );
  });
}
