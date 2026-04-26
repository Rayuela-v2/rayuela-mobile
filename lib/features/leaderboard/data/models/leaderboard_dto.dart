import '../../domain/entities/leaderboard.dart';

/// Wire shape of `GET /leaderboard/:projectId` (rayuela-NodeBackend).
///
/// Canonical response (Mongoose document, leaderboard-user-schema.ts):
///   {
///     projectId: string,
///     lastUpdated: ISO date,
///     users: [
///       { _id: string, username: string, completeName: string,
///         points: number, badges: string[] }
///     ]
///   }
///
/// The DAO is a thin pass-through, but other endpoints have shown that
/// Mongoose serialization sometimes leaks `__v`, `_id` aliases, etc., so
/// we keep parsing defensive — every field has a fallback.
class LeaderboardDto {
  const LeaderboardDto({
    required this.projectId,
    required this.users,
    this.lastUpdated,
  });

  final String projectId;
  final DateTime? lastUpdated;
  final List<LeaderboardUserDto> users;

  /// Tries to read either a bare leaderboard object or a `{ data: {...} }`
  /// envelope. Returns null when the payload doesn't look like a
  /// leaderboard at all.
  static LeaderboardDto? tryParse(Object? raw) {
    final payload = (raw is Map && raw['data'] is Map) ? raw['data'] : raw;
    if (payload is! Map) return null;
    final m = payload.map((k, v) => MapEntry(k.toString(), v));

    final projectId =
        _firstString(m, const ['projectId', '_projectId']) ?? '';

    final usersRaw = m['users'] ?? m['_users'];
    final users = usersRaw is List
        ? usersRaw
            .map(LeaderboardUserDto.tryParse)
            .whereType<LeaderboardUserDto>()
            .toList(growable: false)
        : const <LeaderboardUserDto>[];

    return LeaderboardDto(
      projectId: projectId,
      lastUpdated: _parseDate(m['lastUpdated']) ?? _parseDate(m['updatedAt']),
      users: users,
    );
  }

  /// Sorts by points desc and assigns 1-based ranks. Ties keep the input
  /// order — this matches the frontend's stable-sort behavior.
  Leaderboard toEntity() {
    final sorted = [...users]..sort((a, b) => b.points.compareTo(a.points));
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < sorted.length; i++) {
      final u = sorted[i];
      entries.add(
        LeaderboardEntry(
          rank: i + 1,
          userId: u.id,
          username: u.username,
          completeName: u.completeName,
          points: u.points,
          badges: u.badges,
        ),
      );
    }
    return Leaderboard(
      projectId: projectId,
      lastUpdated: lastUpdated,
      entries: entries,
    );
  }
}

class LeaderboardUserDto {
  const LeaderboardUserDto({
    required this.id,
    required this.username,
    required this.completeName,
    required this.points,
    required this.badges,
  });

  final String id;
  final String username;
  final String completeName;
  final int points;
  final List<String> badges;

  /// Returns null when the row is missing both `_id` and `username` —
  /// it's not a useful leaderboard entry without at least one of them.
  static LeaderboardUserDto? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));

    final id = _firstString(m, const ['_id', 'id', 'userId']) ?? '';
    final username = _firstString(m, const ['username', '_username']) ?? '';
    if (id.isEmpty && username.isEmpty) return null;

    final badgesRaw = m['badges'] ?? m['_badges'];
    final badges = badgesRaw is List
        ? badgesRaw
            .map((e) => e?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return LeaderboardUserDto(
      id: id,
      username: username,
      completeName:
          _firstString(m, const ['completeName', '_completeName', 'name']) ??
              '',
      points: _asInt(m['points']) ?? _asInt(m['_points']) ?? 0,
      badges: badges,
    );
  }
}

// ---------------------------------------------------------------------------
// Defensive parsing helpers — kept private to avoid coupling.
// ---------------------------------------------------------------------------

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    if (v is String) {
      if (v.isEmpty) continue;
      return v;
    }
    if (v is num || v is bool) return v.toString();
  }
  return null;
}

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) {
    final parsed = int.tryParse(v);
    if (parsed != null) return parsed;
    final asDouble = double.tryParse(v);
    return asDouble?.toInt();
  }
  return null;
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
  }
  return null;
}
