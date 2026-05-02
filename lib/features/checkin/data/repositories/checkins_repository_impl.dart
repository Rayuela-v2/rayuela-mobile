import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/outbox/outbox_dao.dart';
import '../../../../core/sync/outbox/outbox_service.dart';
import '../../domain/entities/checkin_history_item.dart';
import '../../domain/entities/checkin_request.dart';
import '../../domain/entities/checkin_submission_outcome.dart';
import '../../domain/repositories/checkins_repository.dart';
import '../sources/checkins_remote_source.dart';

/// Decides at submit-time whether the check-in goes straight to the
/// backend or through the offline outbox.
///
/// Routing rules (per `docs/OFFLINE_SYNC_PLAN.md` §5.1):
///
///   1. **Online** AND **queue empty for this user** → try the network.
///      * Success                             → [CheckinSubmissionAccepted].
///      * Network/timeout/5xx/unknown failure → enqueue + queued outcome.
///      * 4xx the user can act on             → [CheckinSubmissionRejected].
///
///   2. **Offline** OR **queue not empty** → enqueue immediately.
///      Skipping the queue would let new submissions race ahead of
///      older ones and break the "FIFO" contract the UI promises.
class CheckinsRepositoryImpl implements CheckinsRepository {
  const CheckinsRepositoryImpl({
    required CheckinsRemoteSource remote,
    required OutboxService outbox,
    required OutboxDao outboxDao,
    required ConnectivityService connectivity,
    required String Function() currentUserId,
  })  : _remote = remote,
        _outbox = outbox,
        _outboxDao = outboxDao,
        _connectivity = connectivity,
        _currentUserId = currentUserId;

  final CheckinsRemoteSource _remote;
  final OutboxService _outbox;
  final OutboxDao _outboxDao;
  final ConnectivityService _connectivity;
  final String Function() _currentUserId;

  @override
  Future<Result<CheckinSubmissionOutcome>> submitCheckin(
    CheckinRequest request,
  ) async {
    final userId = _currentUserId();
    if (userId.isEmpty) {
      return const Failure(
        UnauthorizedException(
          message: 'You need to log in to submit a check-in',
        ),
      );
    }

    final pending = await _outboxDao.pendingCount(userId);
    final online = await _connectivity.isOnlineForReal();

    if (online && pending == 0) {
      // Mint the idempotency key up-front so the same value is reused
      // when we fall back to enqueueing after a network blip.
      final outcome = await _trySendDirect(request);
      if (outcome != null) return Success(outcome);
    }

    return Success(await _enqueue(request, userId));
  }

  /// Returns null when the direct send was a transient failure → the
  /// caller falls back to the queue. Returns a non-null outcome when
  /// either the request succeeded or the failure is one the user must
  /// see right away.
  Future<CheckinSubmissionOutcome?> _trySendDirect(
    CheckinRequest request,
  ) async {
    final res = await _remote.submit(request);
    if (res case Success(:final value)) {
      return CheckinSubmissionAccepted(value.toEntity());
    }
    final error = (res as Failure).error;
    // A 409 with an idempotency key would land here too, but the
    // direct path doesn't set one; treat any 409 as success defensively
    // (very unlikely in practice).
    if (error is ConflictException) {
      // No CheckinResult to surface — fall through to queue so the
      // user still sees the "pending" reward screen.
      return null;
    }
    if (error is NetworkException ||
        error is TimeoutException ||
        error is ServerException) {
      // Retry territory → queue it.
      return null;
    }
    return CheckinSubmissionRejected(error);
  }

  Future<CheckinSubmissionQueued> _enqueue(
    CheckinRequest request,
    String userId,
  ) async {
    final entry = await _outbox.enqueue(
      userId: userId,
      projectId: request.projectId,
      taskId: request.taskId,
      taskType: request.taskType,
      latitude: request.latitude,
      longitude: request.longitude,
      datetime: request.datetime,
      notes: request.notes,
      sourceImagePaths: request.imagePaths,
    );
    // Best-effort: kick the drainer right away in case we miscounted
    // and we're actually online. If the queue can't go now, the
    // lifecycle/connectivity hooks will pick it up later.
    // ignore: unawaited_futures
    _outbox.drain(userId: userId);
    return CheckinSubmissionQueued(
      outboxId: entry.id,
      queuedAt: entry.createdAt,
    );
  }

  @override
  Future<Result<List<CheckinHistoryItem>>> getUserCheckins(
    String projectId,
  ) async {
    final res = await _remote.fetchUserCheckins(projectId);
    return res.fold(
      onSuccess: (dtos) {
        final items = dtos
            .map((d) => d.toEntity())
            .toList(growable: false)
          // Newest first so the screen lands on the user's most recent
          // contribution. Backend ordering is not guaranteed.
          ..sort((a, b) => b.datetime.compareTo(a.datetime));
        return Success(items);
      },
      onFailure: Failure<List<CheckinHistoryItem>>.new,
    );
  }
}
