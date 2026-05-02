/// Lifecycle of a queued check-in row.
///
/// State transitions:
///
///   ┌───────────┐ enqueue        ┌──────────┐ inflight     ┌────────┐
///   │ (created) │───────────────▶│ pending  │─────────────▶│inflight│
///   └───────────┘                └──────────┘              └───┬────┘
///                                       ▲                     │
///                            schedule    │ retryable error     │ success
///                                       │                     ▼
///                                  ┌────┴─────┐         (row deleted)
///                                  │  failed  │
///                                  └────┬─────┘
///                            permanent  │
///                                       ▼
///                                  ┌──────────┐
///                                  │   dead   │   awaits user action
///                                  └──────────┘
///
/// `failed` is just `pending` with `attempt_count > 0` and a recorded
/// `last_error_*`; we keep them as separate states so the UI can show
/// "queued" vs "retrying" copy without a second column.
enum OutboxStatus { pending, inflight, failed, dead }

extension OutboxStatusWire on OutboxStatus {
  String get wireValue => switch (this) {
        OutboxStatus.pending => 'pending',
        OutboxStatus.inflight => 'inflight',
        OutboxStatus.failed => 'failed',
        OutboxStatus.dead => 'dead',
      };

  static OutboxStatus parse(String? raw) {
    return switch (raw) {
      'pending' => OutboxStatus.pending,
      'inflight' => OutboxStatus.inflight,
      'failed' => OutboxStatus.failed,
      'dead' => OutboxStatus.dead,
      // Defensive: unknown rows revert to pending so the drainer can pick
      // them up and either succeed or transition them properly.
      _ => OutboxStatus.pending,
    };
  }
}

/// One queued check-in submission.
///
/// `id` doubles as the **Idempotency-Key** sent to the backend so a
/// retry after a connection drop never produces a second row server-side
/// (see `docs/OFFLINE_SYNC_PLAN.md` §8 #1).
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.taskType,
    required this.latitude,
    required this.longitude,
    required this.datetime,
    required this.clientCapturedAt,
    required this.images,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.taskId,
    this.notes,
    this.nextAttemptAt,
    this.lastErrorCode,
    this.lastErrorMessage,
  });

  /// UUID v4. Matches the value used as `Idempotency-Key`.
  final String id;
  final String userId;
  final String projectId;
  final String? taskId;
  final String taskType;

  /// Stored as strings end-to-end to mirror the backend's schema (lat/lng
  /// are CHAR(500) on Mongo). The drainer forwards them unchanged.
  final String latitude;
  final String longitude;

  /// Wall-clock the volunteer assigned to the check-in. UTC.
  final DateTime datetime;

  /// Moment the row was first persisted on this device. UTC. Lets the
  /// backend tell apart "captured offline 6 h ago, synced now" from
  /// "captured and synced just now" if it ever needs to.
  final DateTime clientCapturedAt;

  final String? notes;

  final List<OutboxImage> images;

  final OutboxStatus status;
  final int attemptCount;

  /// Earliest moment the drainer should try this row again. `null` means
  /// "now". Updated by the backoff schedule after a retryable failure.
  final DateTime? nextAttemptAt;

  final String? lastErrorCode;
  final String? lastErrorMessage;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Header value to send on `POST /checkin`. Backed by [id] so the
  /// server can replay a previously-stored response.
  String get idempotencyKey => id;

  OutboxEntry copyWith({
    OutboxStatus? status,
    int? attemptCount,
    DateTime? nextAttemptAt,
    String? lastErrorCode,
    String? lastErrorMessage,
    DateTime? updatedAt,
    List<OutboxImage>? images,
  }) {
    return OutboxEntry(
      id: id,
      userId: userId,
      projectId: projectId,
      taskId: taskId,
      taskType: taskType,
      latitude: latitude,
      longitude: longitude,
      datetime: datetime,
      clientCapturedAt: clientCapturedAt,
      notes: notes,
      images: images ?? this.images,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// One image attached to an [OutboxEntry], persisted on disk by
/// [ImageStore]. Position is 0-based and orders the upload.
class OutboxImage {
  const OutboxImage({
    required this.position,
    required this.filePath,
    required this.byteSize,
    required this.mimeType,
  });

  final int position;
  final String filePath;
  final int byteSize;
  final String mimeType;
}
