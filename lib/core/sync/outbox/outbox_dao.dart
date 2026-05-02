import 'package:sqflite/sqflite.dart';

import 'outbox_entry.dart';

/// Data-access layer for the offline check-in outbox.
///
/// Owns two tables created in [AppDatabase] schema v1:
///   * `outbox_checkins`         — one row per queued submission
///   * `outbox_checkin_images`   — N rows per submission (FK + cascade)
///
/// All public methods are transactional where it matters (insert with
/// images, replace images on retry). Repositories never touch the
/// database directly.
class OutboxDao {
  const OutboxDao(this._db);

  final Database _db;

  // ---------------------------------------------------------------------------
  // Inserts
  // ---------------------------------------------------------------------------

  /// Persist a freshly-built [OutboxEntry]. Images are inserted in the
  /// same transaction so partial state is impossible.
  Future<void> insert(OutboxEntry entry) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'outbox_checkins',
        _entryToRow(entry),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      for (final img in entry.images) {
        await txn.insert(
          'outbox_checkin_images',
          {
            'outbox_id': entry.id,
            'position': img.position,
            'file_path': img.filePath,
            'byte_size': img.byteSize,
            'mime_type': img.mimeType,
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// First eligible row for [userId]: `pending` or `failed` whose
  /// `next_attempt_at` is null or in the past.
  ///
  /// Ordering: oldest `created_at` first (FIFO). The drainer takes one
  /// at a time and re-queries between attempts so the user perceives
  /// the queue draining in capture order.
  Future<OutboxEntry?> nextEligible(
    String userId, {
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).toUtc().toIso8601String();
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM outbox_checkins
       WHERE user_id = ?
         AND status IN ('pending','failed')
         AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
       ORDER BY created_at ASC
       LIMIT 1
      ''',
      [userId, cutoff],
    );
    if (rows.isEmpty) return null;
    final imgs = await _imagesFor(rows.first['id'] as String);
    return _rowToEntry(rows.first, imgs);
  }

  /// Every row belonging to [userId], optionally scoped to a single
  /// project. Sorted by `created_at` DESC so the UI lists newest first
  /// (mirrors the history view).
  Future<List<OutboxEntry>> listForUser(
    String userId, {
    String? projectId,
  }) async {
    final where = StringBuffer('user_id = ?');
    final args = <Object?>[userId];
    if (projectId != null) {
      where.write(' AND project_id = ?');
      args.add(projectId);
    }
    final rows = await _db.query(
      'outbox_checkins',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    if (rows.isEmpty) return const [];

    // One image fetch per row keeps the SQL simple. The outbox is small
    // by design (typically < 50 rows). If we ever need to scale we can
    // batch with a single `IN (?,?,…)` query.
    final result = <OutboxEntry>[];
    for (final row in rows) {
      final imgs = await _imagesFor(row['id'] as String);
      result.add(_rowToEntry(row, imgs));
    }
    return result;
  }

  /// Set of every row id currently in the table — used by
  /// [ImageStore.sweepOrphans] to know which folders to keep.
  Future<Set<String>> knownIds() async {
    final rows = await _db.query('outbox_checkins', columns: ['id']);
    return rows.map((r) => r['id'] as String).toSet();
  }

  /// Single-row lookup by id (or null if missing). Used by user-driven
  /// actions like manual retry / discard.
  Future<OutboxEntry?> findById(String id) async {
    final rows = await _db.query(
      'outbox_checkins',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final imgs = await _imagesFor(id);
    return _rowToEntry(rows.first, imgs);
  }

  Future<int> pendingCount(String userId) async {
    final rows = await _db.rawQuery(
      "SELECT COUNT(*) AS c FROM outbox_checkins "
      "WHERE user_id = ? AND status != 'dead'",
      [userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // State transitions
  // ---------------------------------------------------------------------------

  Future<void> markInflight(String id) async {
    await _db.update(
      'outbox_checkins',
      {
        'status': OutboxStatus.inflight.wireValue,
        'updated_at': _nowIso(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(
    String id, {
    required int attemptCount,
    required DateTime nextAttemptAt,
    required String errorCode,
    required String errorMessage,
  }) async {
    await _db.update(
      'outbox_checkins',
      {
        'status': OutboxStatus.failed.wireValue,
        'attempt_count': attemptCount,
        'next_attempt_at': nextAttemptAt.toUtc().toIso8601String(),
        'last_error_code': errorCode,
        'last_error_message': errorMessage,
        'updated_at': _nowIso(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markDead(
    String id, {
    required int attemptCount,
    required String errorCode,
    required String errorMessage,
  }) async {
    await _db.update(
      'outbox_checkins',
      {
        'status': OutboxStatus.dead.wireValue,
        'attempt_count': attemptCount,
        'next_attempt_at': null,
        'last_error_code': errorCode,
        'last_error_message': errorMessage,
        'updated_at': _nowIso(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Drop a row (and its images via FK cascade). Called after a
  /// successful POST or after the user discards a `dead` entry.
  Future<void> delete(String id) async {
    await _db.delete('outbox_checkins', where: 'id = ?', whereArgs: [id]);
  }

  /// Reset an `inflight` row back to `pending` if it has been stuck for
  /// longer than [staleAfter]. Protects against a drainer crash leaving
  /// a row marked inflight forever.
  Future<int> reclaimStaleInflight({
    Duration staleAfter = const Duration(minutes: 10),
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(staleAfter).toIso8601String();
    return _db.rawUpdate(
      '''
      UPDATE outbox_checkins
         SET status = 'pending',
             updated_at = ?
       WHERE status = 'inflight'
         AND updated_at < ?
      ''',
      [_nowIso(), cutoff],
    );
  }

  // ---------------------------------------------------------------------------
  // Mappers
  // ---------------------------------------------------------------------------

  Future<List<OutboxImage>> _imagesFor(String outboxId) async {
    final rows = await _db.query(
      'outbox_checkin_images',
      where: 'outbox_id = ?',
      whereArgs: [outboxId],
      orderBy: 'position ASC',
    );
    return rows
        .map(
          (r) => OutboxImage(
            position: r['position'] as int,
            filePath: r['file_path'] as String,
            byteSize: r['byte_size'] as int,
            mimeType: r['mime_type'] as String,
          ),
        )
        .toList(growable: false);
  }

  Map<String, Object?> _entryToRow(OutboxEntry e) {
    return {
      'id': e.id,
      'user_id': e.userId,
      'project_id': e.projectId,
      'task_id': e.taskId,
      'task_type': e.taskType,
      'latitude': e.latitude,
      'longitude': e.longitude,
      'datetime_iso': e.datetime.toUtc().toIso8601String(),
      'client_captured_at': e.clientCapturedAt.toUtc().toIso8601String(),
      'notes': e.notes,
      'status': e.status.wireValue,
      'attempt_count': e.attemptCount,
      'next_attempt_at': e.nextAttemptAt?.toUtc().toIso8601String(),
      'last_error_code': e.lastErrorCode,
      'last_error_message': e.lastErrorMessage,
      'created_at': e.createdAt.toUtc().toIso8601String(),
      'updated_at': e.updatedAt.toUtc().toIso8601String(),
    };
  }

  OutboxEntry _rowToEntry(
    Map<String, Object?> row,
    List<OutboxImage> images,
  ) {
    return OutboxEntry(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      projectId: row['project_id'] as String,
      taskId: row['task_id'] as String?,
      taskType: row['task_type'] as String,
      latitude: row['latitude'] as String,
      longitude: row['longitude'] as String,
      datetime: DateTime.parse(row['datetime_iso'] as String),
      clientCapturedAt: DateTime.parse(row['client_captured_at'] as String),
      notes: row['notes'] as String?,
      images: images,
      status: OutboxStatusWire.parse(row['status'] as String?),
      attemptCount: (row['attempt_count'] as int?) ?? 0,
      nextAttemptAt: _parseNullableDate(row['next_attempt_at']),
      lastErrorCode: row['last_error_code'] as String?,
      lastErrorMessage: row['last_error_message'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  static DateTime? _parseNullableDate(Object? raw) {
    if (raw == null) return null;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
