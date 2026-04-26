/// Per-project ranking of volunteers. Mirrors the backend's
/// `Leaderboard` document (rayuela-NodeBackend/.../leaderboard-user-schema.ts):
/// one row per user, with the running points + earned badges. The mobile
/// "Progress" tab uses this to give the user a competitive readout — both
/// where they stand globally and how their badges compare.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.completeName,
    required this.points,
    required this.badges,
    required this.rank,
  });

  /// 1-based position in the sorted list. Set by the repository when it
  /// orders rows by points desc — UIs should NOT recompute it.
  final int rank;

  final String userId;
  final String username;
  final String completeName;
  final int points;
  final List<String> badges;

  int get badgesCount => badges.length;

  /// Friendly display name. Falls back to the username when the volunteer
  /// hasn't filled in their full name yet.
  String get displayName {
    final n = completeName.trim();
    return n.isEmpty ? username : n;
  }
}

class Leaderboard {
  const Leaderboard({
    required this.projectId,
    required this.entries,
    this.lastUpdated,
  });

  final String projectId;
  final DateTime? lastUpdated;

  /// Sorted by points desc, with [LeaderboardEntry.rank] already populated.
  final List<LeaderboardEntry> entries;

  bool get isEmpty => entries.isEmpty;

  /// Look up the row for a specific user. Returns null when the user has
  /// no points/badges in this project yet (backend omits them entirely
  /// in that case).
  LeaderboardEntry? entryForUser(String userId) {
    for (final e in entries) {
      if (e.userId == userId) return e;
    }
    return null;
  }
}
