
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/error/app_exception.dart';
import 'package:rayuela_mobile/core/error/result.dart';
import 'package:rayuela_mobile/core/sync/connectivity_service.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_dao.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_entry.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_service.dart';
import 'package:rayuela_mobile/features/checkin/data/repositories/checkins_repository_impl.dart';
import 'package:rayuela_mobile/features/checkin/data/sources/checkins_remote_source.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_request.dart';
import 'package:rayuela_mobile/features/checkin/data/models/checkin_dtos.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_submission_outcome.dart';

class _MockRemote extends Mock implements CheckinsRemoteSource {}
class _MockOutbox extends Mock implements OutboxService {}
class _MockDao extends Mock implements OutboxDao {}
class _MockConnectivity extends Mock implements ConnectivityService {}

CheckinRequest _req() => CheckinRequest(
      projectId: 'p1',
      taskId: 't1',
      taskType: 'observation',
      latitude: '0',
      longitude: '0',
      datetime: DateTime.utc(2026, 5, 16, 12),
      notes: null,
      imagePaths: const ['/tmp/x.jpg'],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_req());
  });

  late _MockRemote remote;
  late _MockOutbox outbox;
  late _MockDao dao;
  late _MockConnectivity connectivity;

  setUp(() {
    remote = _MockRemote();
    outbox = _MockOutbox();
    dao = _MockDao();
    connectivity = _MockConnectivity();
  });

  CheckinsRepositoryImpl build() => CheckinsRepositoryImpl(
        remote: remote,
        outbox: outbox,
        outboxDao: dao,
        connectivity: connectivity,
        currentUserId: () => 'u1',
      );

  CheckinResultDto _fakeDto() => CheckinResultDto(
        id: 'srv-1',
        pointsAwarded: 10,
        newBadges: const [],
        imageRefs: const [],
        timestamp: DateTime.utc(2026, 5, 16, 12),
      );

  void _stubEnqueueOk() {
    when(() => outbox.enqueue(
          id: any(named: 'id'),
          userId: any(named: 'userId'),
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
          taskType: any(named: 'taskType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          datetime: any(named: 'datetime'),
          notes: any(named: 'notes'),
          sourceImagePaths: any(named: 'sourceImagePaths'),
        )).thenAnswer((inv) async {
      final id = (inv.namedArguments[#id] as String?) ?? 'gen-id';
      return OutboxEntry(
        id: id,
        userId: 'u1',
        projectId: 'p1',
        taskId: 't1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 16, 12),
        clientCapturedAt: DateTime.utc(2026, 5, 16, 12),
        images: const [],
        status: OutboxStatus.pending,
        attemptCount: 0,
        createdAt: DateTime.utc(2026, 5, 16, 12),
        updatedAt: DateTime.utc(2026, 5, 16, 12),
      );
    });
    when(() => outbox.drain(userId: any(named: 'userId'))).thenAnswer((_) async {});
  }

  test('online + empty queue: direct submit uses the same UUID as fallback enqueue', () async {
    when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
    when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);

    // Direct submit times out — repository must fall through to enqueue.
    when(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((_) async => const Failure(TimeoutException()));

    final captured = <String>[];
    when(() => outbox.enqueue(
          id: any(named: 'id'),
          userId: any(named: 'userId'),
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
          taskType: any(named: 'taskType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          datetime: any(named: 'datetime'),
          notes: any(named: 'notes'),
          sourceImagePaths: any(named: 'sourceImagePaths'),
        )).thenAnswer((inv) async {
      final id = inv.namedArguments[#id] as String;
      captured.add(id);
      return OutboxEntry(
        id: id,
        userId: 'u1',
        projectId: 'p1',
        taskId: 't1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 16, 12),
        clientCapturedAt: DateTime.utc(2026, 5, 16, 12),
        images: const [],
        status: OutboxStatus.pending,
        attemptCount: 0,
        createdAt: DateTime.utc(2026, 5, 16, 12),
        updatedAt: DateTime.utc(2026, 5, 16, 12),
      );
    });
    when(() => outbox.drain(userId: any(named: 'userId')))
        .thenAnswer((_) async {});

    final result = await build().submitCheckin(_req());

    // Capture the key passed to the remote.
    final keyOnDirect = verify(() => remote.submit(
          any(),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        )).captured.single as String;

    expect(captured, hasLength(1), reason: 'enqueue must have been called once');
    expect(captured.single, keyOnDirect,
        reason: 'enqueue id must equal the Idempotency-Key sent on the failed direct submit');

    expect(result, isA<Success<CheckinSubmissionOutcome>>());
    final outcome = (result as Success<CheckinSubmissionOutcome>).value;
    expect(outcome, isA<CheckinSubmissionQueued>());
  });

  test('online + empty queue + 2xx: returns Accepted, does not touch outbox', () async {
    when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
    when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);
    when(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((_) async => Success(_fakeDto()));

    final result = await build().submitCheckin(_req());

    expect(result, isA<Success<CheckinSubmissionOutcome>>());
    final outcome = (result as Success<CheckinSubmissionOutcome>).value;
    expect(outcome, isA<CheckinSubmissionAccepted>());
    verifyNever(() => outbox.enqueue(
          id: any(named: 'id'),
          userId: any(named: 'userId'),
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
          taskType: any(named: 'taskType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          datetime: any(named: 'datetime'),
          notes: any(named: 'notes'),
          sourceImagePaths: any(named: 'sourceImagePaths'),
        ));
  });

  test('online + empty queue + 4xx validation: returns Rejected, does not enqueue', () async {
    when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
    when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);
    when(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((_) async => Failure(ValidationException(
              message: 'bad',
              fieldErrors: const {},
            )));

    final result = await build().submitCheckin(_req());
    final outcome = (result as Success<CheckinSubmissionOutcome>).value;
    expect(outcome, isA<CheckinSubmissionRejected>());
    verifyNever(() => outbox.enqueue(
          id: any(named: 'id'),
          userId: any(named: 'userId'),
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
          taskType: any(named: 'taskType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          datetime: any(named: 'datetime'),
          notes: any(named: 'notes'),
          sourceImagePaths: any(named: 'sourceImagePaths'),
        ));
  });

  test('offline: enqueues without touching remote', () async {
    when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
    when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => false);
    _stubEnqueueOk();

    final result = await build().submitCheckin(_req());
    expect((result as Success).value, isA<CheckinSubmissionQueued>());
    verifyNever(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')));
  });

  test('online + non-empty queue: enqueues to preserve FIFO, skips remote', () async {
    when(() => dao.pendingCount('u1')).thenAnswer((_) async => 3);
    when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);
    _stubEnqueueOk();

    final result = await build().submitCheckin(_req());
    expect((result as Success).value, isA<CheckinSubmissionQueued>());
    verifyNever(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')));
  });
}
