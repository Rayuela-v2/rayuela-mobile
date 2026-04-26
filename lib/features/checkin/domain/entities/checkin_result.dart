/// Domain representation of the response to `POST /checkin`.
///
/// The wire shape is:
///   {
///     id, checkin: { ... }, gameStatus: { newBadges, newPoints,
///     newLeaderboard }, score, timestamp, contributesTo?: { name, id }
///   }
class CheckinResult {
  const CheckinResult({
    required this.id,
    required this.pointsAwarded,
    required this.newBadges,
    required this.imageRefs,
    required this.timestamp,
    this.score,
    this.contributesTo,
    this.message,
  });

  final String id;
  final int pointsAwarded;
  final List<BadgeAward> newBadges;
  final List<String> imageRefs;
  final DateTime timestamp;
  final int? score;
  final TaskReference? contributesTo;

  /// Optional human-readable message to surface ("You scored 5/5", etc.).
  final String? message;
}

class BadgeAward {
  const BadgeAward({
    required this.name,
    this.description,
  });

  final String name;
  final String? description;
}

class TaskReference {
  const TaskReference({required this.id, required this.name});

  final String id;
  final String name;
}
