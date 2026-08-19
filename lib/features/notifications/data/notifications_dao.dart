import 'package:sqflite/sqflite.dart';

import '../domain/entities/app_notification.dart';

/// Storage for the notification centre.
///
/// Everything is scoped by `user_id`: two accounts on one device must never
/// see each other's notifications.
class NotificationsDao {
  NotificationsDao(this._db);

  final Database _db;

  static const String _table = 'app_notifications';

  /// Inserts events that aren't already recorded.
  ///
  /// Dedupe rides entirely on the deterministic primary key, so calling this
  /// on every sync is safe and cheap — the second time round every row
  /// conflicts and is ignored. Returns how many were genuinely new, which is
  /// what the caller uses to decide whether anything is worth surfacing.
  Future<int> recordAll(String userId, List<AppNotification> events) async {
    if (events.isEmpty) return 0;

    var inserted = 0;
    final batch = _db.batch();
    for (final e in events) {
      batch.insert(
        _table,
        e.toRow(userId),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    // `insert` with IGNORE returns 0 for a conflicting row and the rowid
    // otherwise, so the results tell us which ones actually landed.
    final results = await batch.commit(noResult: false);
    for (final r in results) {
      if (r is int && r > 0) inserted++;
    }
    return inserted;
  }

  /// Subjects in this project we've already raised [type] about.
  ///
  /// Lets the recorder ask "did we ever tell them this badge was fading?"
  /// before announcing that it expired.
  Future<Set<String>> subjectsWithType({
    required String userId,
    required String projectId,
    required AppNotificationType type,
  }) async {
    final rows = await _db.query(
      _table,
      columns: ['subject'],
      where: 'user_id = ? AND project_id = ? AND type = ?',
      whereArgs: [userId, projectId, type.wire],
    );
    return rows.map((r) => r['subject'] as String? ?? '').toSet();
  }

  Future<List<AppNotification>> list(String userId, {int limit = 100}) async {
    final rows = await _db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(AppNotification.fromRow)
        .whereType<AppNotification>()
        .toList(growable: false);
  }

  Future<int> unreadCount(String userId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE user_id = ? AND read_at IS NULL',
      [userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Oldest un-popped event for a project, or null when there's nothing new
  /// to interrupt with. Oldest-first on purpose: if two badges started
  /// fading, the one that has been waiting longest is the more urgent news.
  Future<AppNotification?> nextUnseen({
    required String userId,
    required String projectId,
  }) async {
    final rows = await _db.query(
      _table,
      where: 'user_id = ? AND project_id = ? AND seen_at IS NULL',
      whereArgs: [userId, projectId],
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppNotification.fromRow(rows.first);
  }

  Future<void> markSeen(String id) => _db.update(
        _table,
        {'seen_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> markAllRead(String userId) => _db.update(
        _table,
        {'read_at': DateTime.now().toIso8601String()},
        where: 'user_id = ? AND read_at IS NULL',
        whereArgs: [userId],
      );
}
