import '../../domain/entities/checkin_result.dart';

/// Wire shape of the response to `POST /checkin`.
///
/// The backend's response is shaped like:
///   {
///     id: "checkinId",
///     checkin: {
///       id, latitude, longitude, date, projectId,
///       user: { ...User entity (underscore-leaks!) },
///       taskType, contributesTo, imageRefs
///     },
///     gameStatus: {
///       newBadges: [{ name, description? }, ...],
///       newPoints: number,
///       newLeaderboard: [...]
///     },
///     score: 0..5,
///     timestamp: Date,
///     contributesTo?: { name, id }
///   }
///
/// We parse defensively: any field can be missing or shaped differently,
/// and a malformed `gameStatus` should not take the whole result down.
class CheckinResultDto {
  const CheckinResultDto({
    required this.id,
    required this.pointsAwarded,
    required this.newBadges,
    required this.imageRefs,
    required this.timestamp,
    this.score,
    this.contributesTo,
  });

  final String id;
  final int pointsAwarded;
  final List<BadgeAwardDto> newBadges;
  final List<String> imageRefs;
  final DateTime timestamp;
  final int? score;
  final TaskReferenceDto? contributesTo;

  factory CheckinResultDto.fromJson(Object? raw) {
    final json = _asMap(raw);
    final checkin = _asMap(json['checkin']);
    final gameStatus = _asMap(json['gameStatus']);
    final contributes = json['contributesTo'];

    final imageRefsRaw = checkin['imageRefs'] ?? json['imageRefs'];
    final imageRefs = imageRefsRaw is List
        ? imageRefsRaw.map((r) => r.toString()).toList(growable: false)
        : const <String>[];

    final newBadgesRaw = gameStatus['newBadges'] ?? const <dynamic>[];
    final newBadges = newBadgesRaw is List
        ? newBadgesRaw
            .map(BadgeAwardDto.tryParse)
            .whereType<BadgeAwardDto>()
            .toList(growable: false)
        : const <BadgeAwardDto>[];

    final timestamp = _parseDate(json['timestamp']) ??
        _parseDate(checkin['date']) ??
        DateTime.now();

    return CheckinResultDto(
      id: _firstString(json, const ['id', '_id']) ??
          _firstString(checkin, const ['id', '_id']) ??
          '',
      pointsAwarded: _asInt(gameStatus['newPoints']) ?? 0,
      newBadges: newBadges,
      imageRefs: imageRefs,
      timestamp: timestamp,
      score: _asInt(json['score']),
      contributesTo: TaskReferenceDto.tryParse(contributes),
    );
  }

  CheckinResult toEntity() {
    final message = _composeMessage();
    return CheckinResult(
      id: id,
      pointsAwarded: pointsAwarded,
      newBadges:
          newBadges.map((b) => b.toEntity()).toList(growable: false),
      imageRefs: imageRefs,
      timestamp: timestamp,
      score: score,
      contributesTo: contributesTo?.toEntity(),
      message: message,
    );
  }

  String? _composeMessage() {
    if (score == null) return null;
    return 'Quality score: $score/5';
  }
}

class BadgeAwardDto {
  const BadgeAwardDto({required this.name, this.description});

  final String name;
  final String? description;

  static BadgeAwardDto? tryParse(Object? raw) {
    if (raw is String) {
      // Sometimes a badge is just a name. Tolerate it.
      if (raw.isEmpty) return null;
      return BadgeAwardDto(name: raw);
    }
    if (raw is Map) {
      final json = raw.map((k, v) => MapEntry(k.toString(), v));
      final name = _firstString(json, const ['name', '_name']);
      if (name == null || name.isEmpty) return null;
      return BadgeAwardDto(
        name: name,
        description: _firstString(json, const ['description', '_description']),
      );
    }
    return null;
  }

  BadgeAward toEntity() => BadgeAward(name: name, description: description);
}

class TaskReferenceDto {
  const TaskReferenceDto({required this.id, required this.name});

  final String id;
  final String name;

  static TaskReferenceDto? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.map((k, v) => MapEntry(k.toString(), v));
    final id = _firstString(json, const ['id', '_id']);
    final name = _firstString(json, const ['name']);
    if (id == null && name == null) return null;
    return TaskReferenceDto(id: id ?? '', name: name ?? '');
  }

  TaskReference toEntity() => TaskReference(id: id, name: name);
}

// ---------------------------------------------------------------------------
// Defensive parsing helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const <String, dynamic>{};
}

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
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
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
