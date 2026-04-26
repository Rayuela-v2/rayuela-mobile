import '../../domain/entities/project_summary.dart';

/// Mirrors the shape returned by `GET /volunteer/projects`,
/// `GET /volunteer/public/projects` and `GET /projects/:id`.
///
/// `GET /volunteer/projects` returns the raw project documents spread with
/// `subscribed: bool` (see VolunteerService.mapSubscriptions). There is no
/// `user` sub-object on the project — per-user `points` and `badges` live
/// on the current user's `_gameProfiles` array, which is stitched in by
/// [ProjectsRepositoryImpl] from `GET /user`.
///
/// We accept all reasonable spellings of every field — `_id`/`id`,
/// `subscribed`/`isSubscribed`, etc. — and never blind-cast null.
class ProjectDto {
  const ProjectDto({
    required this.id,
    required this.name,
    required this.description,
    required this.available,
    this.image,
    this.web,
    this.isSubscribed = false,
    this.userPoints = 0,
    this.userBadgesCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final bool available;
  final String? image;
  final String? web;
  final bool isSubscribed;
  final int userPoints;
  final int userBadgesCount;

  factory ProjectDto.fromJson(Object? raw) {
    final json = _asMap(raw);
    return ProjectDto(
      id: _firstString(json, const ['_id', 'id']) ?? '',
      name: _firstString(json, const ['name']) ?? '',
      description: _firstString(json, const ['description']) ?? '',
      available: _asBool(json['available']) ?? false,
      image: _firstString(json, const ['image']),
      web: _firstString(json, const ['web']),
      isSubscribed:
          _asBool(json['subscribed'] ?? json['isSubscribed']) ?? false,
      userPoints: _asInt(json['userPoints']) ?? 0,
      userBadgesCount: _asInt(json['userBadgesCount']) ?? 0,
    );
  }

  /// Returns a copy with per-user gamification stats applied. Used by the
  /// repository to stitch in the current user's `gameProfiles` entry.
  ProjectDto withUserStats({required int points, required int badgesCount}) {
    return ProjectDto(
      id: id,
      name: name,
      description: description,
      available: available,
      image: image,
      web: web,
      isSubscribed: isSubscribed,
      userPoints: points,
      userBadgesCount: badgesCount,
    );
  }

  ProjectSummary toEntity() => ProjectSummary(
        id: id,
        name: name,
        description: description,
        available: available,
        imageUrl: image,
        website: web,
        isSubscribed: isSubscribed,
        userPoints: userPoints,
        userBadgesCount: userBadgesCount,
      );
}

// ---------------------------------------------------------------------------
// Defensive parsing helpers (kept module-private to avoid an import dance).
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

bool? _asBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}
