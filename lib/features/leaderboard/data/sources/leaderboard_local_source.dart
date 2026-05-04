import 'package:sqflite/sqflite.dart';

import '../../../../core/cache/cached_value.dart';
import '../../../../core/cache/json_cache_table.dart';
import '../../domain/entities/leaderboard.dart';

/// Caches the per-project leaderboard for offline display.
///
/// One row per (userId, projectId) in `cached_leaderboards`. Stored
/// payload includes `lastUpdated` so the offline view can show the
/// volunteer how fresh the snapshot is.
class LeaderboardLocalSource {
  LeaderboardLocalSource(Database db)
      : _table = JsonCacheTable<Leaderboard>(
          db: db,
          table: 'cached_leaderboards',
          encode: _encode,
          decode: _decode,
        );

  final JsonCacheTable<Leaderboard> _table;

  Future<Cached<Leaderboard>?> read({
    required String userId,
    required String projectId,
  }) {
    return _table.read(userId: userId, projectId: projectId);
  }

  Future<void> write({
    required String userId,
    required String projectId,
    required Leaderboard leaderboard,
    required DateTime fetchedAt,
  }) {
    return _table.write(
      userId: userId,
      projectId: projectId,
      value: leaderboard,
      fetchedAt: fetchedAt,
    );
  }

  Future<void> clearForUser(String userId) => _table.clearForUser(userId);
}

Object _encode(Leaderboard l) => {
      'projectId': l.projectId,
      'lastUpdated': l.lastUpdated?.toUtc().toIso8601String(),
      'entries': [
        for (final e in l.entries)
          {
            'rank': e.rank,
            'userId': e.userId,
            'username': e.username,
            'completeName': e.completeName,
            'points': e.points,
            'badges': e.badges,
          },
      ],
    };

Leaderboard _decode(Object? raw) {
  if (raw is! Map) return const Leaderboard(projectId: '', entries: []);
  final entriesRaw = raw['entries'];
  final entries = <LeaderboardEntry>[];
  if (entriesRaw is List) {
    for (final m in entriesRaw.whereType<Map>()) {
      final badgesRaw = m['badges'];
      final badges = <String>[];
      if (badgesRaw is List) {
        badges.addAll(badgesRaw.map((b) => b.toString()));
      }
      entries.add(
        LeaderboardEntry(
          rank: _asInt(m['rank']),
          userId: (m['userId'] ?? '').toString(),
          username: (m['username'] ?? '').toString(),
          completeName: (m['completeName'] ?? '').toString(),
          points: _asInt(m['points']),
          badges: badges,
        ),
      );
    }
  }
  return Leaderboard(
    projectId: (raw['projectId'] ?? '').toString(),
    entries: entries,
    lastUpdated: raw['lastUpdated'] is String
        ? DateTime.tryParse(raw['lastUpdated'] as String)
        : null,
  );
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
