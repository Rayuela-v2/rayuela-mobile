import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'cached_value.dart';

/// Thin helper around the four `cached_*` tables created in
/// [AppDatabase] schema v1. Each table has the same shape — `(user_id,
/// project_id)` PK + `payload_json` + `fetched_at` — so factoring the
/// CRUD into a single class saves ~30 lines per local source.
///
/// The helper does not know how to encode the value: callers pass an
/// `encode` / `decode` pair that maps the entity to/from a JSON-able
/// `Object?` (typically a `Map` or a `List<Map>`).
class JsonCacheTable<T> {
  JsonCacheTable({
    required this.db,
    required this.table,
    required this.encode,
    required this.decode,
  });

  final Database db;
  final String table;
  final Object? Function(T value) encode;
  final T Function(Object? json) decode;

  /// Fetches the cached entry for [userId]/[projectId]. Returns `null`
  /// when the row is missing, when the JSON fails to parse, or when
  /// the fetched_at column is invalid — the SWR helper treats `null`
  /// the same as "no cache" and falls through to the remote call.
  Future<Cached<T>?> read({
    required String userId,
    required String projectId,
  }) async {
    final rows = await db.query(
      table,
      where: 'user_id = ? AND project_id = ?',
      whereArgs: [userId, projectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final raw = jsonDecode(rows.first['payload_json'] as String);
      final fetchedAt = DateTime.parse(rows.first['fetched_at'] as String);
      return Cached(value: decode(raw), fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }

  /// Upsert. Schemas don't expose UNIQUE on the PK at the SQLite level
  /// for these tables (`PRIMARY KEY` is enough), so a `REPLACE` does
  /// the right thing.
  Future<void> write({
    required String userId,
    required String projectId,
    required T value,
    required DateTime fetchedAt,
  }) async {
    await db.insert(
      table,
      {
        'user_id': userId,
        'project_id': projectId,
        'payload_json': jsonEncode(encode(value)),
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete({
    required String userId,
    required String projectId,
  }) async {
    await db.delete(
      table,
      where: 'user_id = ? AND project_id = ?',
      whereArgs: [userId, projectId],
    );
  }

  /// Remove every row owned by [userId]. Used on logout to wipe a
  /// previous account's cache.
  Future<void> clearForUser(String userId) async {
    await db.delete(table, where: 'user_id = ?', whereArgs: [userId]);
  }
}
