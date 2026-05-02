import 'dart:async';

import 'package:mutex/mutex.dart';
import 'package:uuid/uuid.dart';

import '../../storage/image_store.dart';
import '../connectivity_service.dart';
import 'backoff_strategy.dart';
import 'outbox_dao.dart';
import 'outbox_entry.dart';
import 'outbox_sender.dart';
import 'sync_status.dart';

/// Orchestrates the offline check-in outbox.
///
/// Two responsibilities:
///   * **enqueue** a freshly-composed check-in: persist images via
///     [ImageStore], insert a row in [OutboxDao].
///   * **drain** eligible rows in FIFO order, sending one at a time
///     under a [Mutex] so concurrent triggers (lifecycle resume,
///     connectivity stream, manual retry) don't race.
///
/// The "how do I actually upload this" step is delegated to an
/// [OutboxSender] so the `core/` layer stays free of feature-specific
/// HTTP knowledge. `bootstrap.dart` wires the concrete sender for the
/// check-in feature.
///
/// Designed to be cheap when there's nothing to do: [drain] short-
/// circuits if the connectivity probe says the backend is unreachable
/// or if [OutboxDao.nextEligible] returns null.
class OutboxService {
  OutboxService({
    required OutboxDao dao,
    required ImageStore imageStore,
    required ConnectivityService connectivity,
    required OutboxSender sender,
    Uuid? uuid,
    BackoffStrategy? backoff,
    DateTime Function()? clock,
  })  : _dao = dao,
        _imageStore = imageStore,
        _connectivity = connectivity,
        _sender = sender,
        _uuid = uuid ?? const Uuid(),
        _backoff = backoff ?? JitteredExponentialBackoff(),
        _clock = clock ?? DateTime.now;

  final OutboxDao _dao;
  final ImageStore _imageStore;
  final ConnectivityService _connectivity;
  final OutboxSender _sender;
  final Uuid _uuid;
  final BackoffStrategy _backoff;
  final DateTime Function() _clock;

  final Mutex _drainLock = Mutex();
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.idle;

  SyncStatus get status => _status;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Emits whenever a row is enqueued, sent, retried, or discarded.
  /// The payload is the affected outbox id, or `null` for "many rows
  /// changed" events (end of a drain cycle). Riverpod listeners use it
  /// to invalidate the pending-checkins providers.
  Stream<String?> get changes => _changesController.stream;
  final StreamController<String?> _changesController =
      StreamController<String?>.broadcast();

  Future<void> dispose() async {
    if (!_statusController.isClosed) await _statusController.close();
    if (!_changesController.isClosed) await _changesController.close();
  }

  /// Exposed for tests / debug tooling. Production callers should go
  /// through the service API.
  OutboxDao get rawDao => _dao;

  // ---------------------------------------------------------------------------
  // Enqueue
  // ---------------------------------------------------------------------------

  /// Persist the user's check-in for later upload. Returns the resulting
  /// [OutboxEntry] (status = `pending`).
  ///
  /// Image paths are read from disk, compressed, and copied into the
  /// app sandbox (so the system purging the OS cache directory doesn't
  /// lose them) before the SQLite row is inserted. If anything fails
  /// we roll back the on-disk folder and rethrow.
  Future<OutboxEntry> enqueue({
    required String userId,
    required String projectId,
    String? taskId,
    required String taskType,
    required String latitude,
    required String longitude,
    required DateTime datetime,
    String? notes,
    required List<String> sourceImagePaths,
  }) async {
    final id = _uuid.v4();
    final now = _clock().toUtc();

    final stored = await _imageStore.persist(
      outboxId: id,
      sourcePaths: sourceImagePaths,
    );
    final images = [
      for (var i = 0; i < stored.length; i++)
        OutboxImage(
          position: i,
          filePath: stored[i].path,
          byteSize: stored[i].byteSize,
          mimeType: stored[i].mimeType,
        ),
    ];

    final entry = OutboxEntry(
      id: id,
      userId: userId,
      projectId: projectId,
      taskId: taskId,
      taskType: taskType,
      latitude: latitude,
      longitude: longitude,
      datetime: datetime.toUtc(),
      clientCapturedAt: now,
      notes: notes,
      images: images,
      status: OutboxStatus.pending,
      attemptCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _dao.insert(entry);
    } catch (e) {
      // Roll back the orphan folder so a retry doesn't pile up bytes.
      await _imageStore.deleteForOutbox(id);
      rethrow;
    }
    _changesController.add(id);
    return entry;
  }

  // ---------------------------------------------------------------------------
  // Drain
  // ---------------------------------------------------------------------------

  /// Process eligible rows for [userId] until the queue is empty, the
  /// network drops, or [maxPerCycle] sends have completed.
  ///
  /// Safe to call from multiple triggers — concurrent invocations are
  /// serialised by [_drainLock]. A second call while the first is still
  /// running returns immediately (the work-in-progress will pick up
  /// any new rows enqueued in the meantime).
  Future<void> drain({
    required String userId,
    int maxPerCycle = 50,
  }) async {
    if (_drainLock.isLocked) return;
    await _drainLock.protect(() => _drainLoop(userId, maxPerCycle));
  }

  Future<void> _drainLoop(String userId, int maxPerCycle) async {
    // Re-claim any inflight rows left over from a crashed previous run.
    await _dao.reclaimStaleInflight();

    final online = await _connectivity.isOnlineForReal();
    if (!online) {
      _emitStatus(SyncStatus.offline);
      return;
    }

    var processed = 0;
    var sawError = false;
    var stoppedEarly = false;
    while (processed < maxPerCycle) {
      final entry = await _dao.nextEligible(userId, now: _clock());
      if (entry == null) break;

      _emitStatus(SyncStatus.syncing);
      await _dao.markInflight(entry.id);

      final outcome = await _sender.send(entry);
      switch (outcome) {
        case OutboxSendSucceeded():
          await _imageStore.deleteForOutbox(entry.id);
          await _dao.delete(entry.id);
          _changesController.add(entry.id);
          processed++;
        case OutboxSendAlreadyExists():
          // Backend says "I already have this row". Treat as success.
          await _imageStore.deleteForOutbox(entry.id);
          await _dao.delete(entry.id);
          _changesController.add(entry.id);
          processed++;
        case OutboxSendRetryable(:final code, :final message):
          final nextAttempt = entry.attemptCount + 1;
          if (nextAttempt >= _backoff.maxAttempts) {
            await _dao.markDead(
              entry.id,
              attemptCount: nextAttempt,
              errorCode: code,
              errorMessage: message,
            );
            sawError = true;
          } else {
            await _dao.markFailed(
              entry.id,
              attemptCount: nextAttempt,
              nextAttemptAt: _clock().add(_backoff.delayFor(nextAttempt)),
              errorCode: code,
              errorMessage: message,
            );
          }
          _changesController.add(entry.id);
          // Bail so we don't bombard the server while it's struggling.
          stoppedEarly = true;
        case OutboxSendPermanent(:final code, :final message):
          await _dao.markDead(
            entry.id,
            attemptCount: entry.attemptCount + 1,
            errorCode: code,
            errorMessage: message,
          );
          _changesController.add(entry.id);
          sawError = true;
          processed++;
      }
      if (stoppedEarly) break;
    }

    _emitStatus(sawError ? SyncStatus.error : SyncStatus.idle);
    _changesController.add(null);
  }

  // ---------------------------------------------------------------------------
  // User-driven actions
  // ---------------------------------------------------------------------------

  /// Force the row to be eligible immediately (resets backoff). Returns
  /// `false` if the id no longer exists (e.g. it was just sent).
  Future<bool> retry(String id) async {
    final row = await _dao.findById(id);
    if (row == null) return false;
    await _dao.markFailed(
      id,
      attemptCount: row.attemptCount,
      nextAttemptAt: _clock(),
      errorCode: 'manual_retry',
      errorMessage: 'User requested immediate retry',
    );
    _changesController.add(id);
    return true;
  }

  /// Drop a row and its images. Used for "Discard" on dead rows.
  Future<void> discard(String id) async {
    await _imageStore.deleteForOutbox(id);
    await _dao.delete(id);
    _changesController.add(id);
  }

  void _emitStatus(SyncStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }
}
