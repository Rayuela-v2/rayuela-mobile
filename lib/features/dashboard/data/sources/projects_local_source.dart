import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/cache/cached_value.dart';
import '../../../../core/cache/json_cache_table.dart';
import '../../domain/entities/project_area.dart';
import '../../domain/entities/project_detail.dart';
import '../../domain/entities/project_summary.dart';

/// Persists the read-side projects cache for offline use.
///
/// Storage layout, all in `cached_projects`:
///   * one sentinel row per user (`project_id == '__subscribed__'`)
///     carrying the entire subscribed-projects list as JSON;
///   * one row per project the user has visited
///     (`project_id == <id>`) carrying the [ProjectDetail] payload.
///
/// Keeping the list in a single sentinel row mirrors the way the
/// dashboard fetches it (one HTTP call → one cached envelope) and
/// avoids fanning out reads on every dashboard open.
class ProjectsLocalSource {
  ProjectsLocalSource(Database db)
      : _summaryTable = JsonCacheTable<List<ProjectSummary>>(
          db: db,
          table: 'cached_projects',
          encode: _encodeSummaryList,
          decode: _decodeSummaryList,
        ),
        _detailTable = JsonCacheTable<ProjectDetail>(
          db: db,
          table: 'cached_projects',
          encode: _encodeDetail,
          decode: _decodeDetail,
        );

  static const String _subscribedSentinel = '__subscribed__';

  final JsonCacheTable<List<ProjectSummary>> _summaryTable;
  final JsonCacheTable<ProjectDetail> _detailTable;

  // ---------------------------------------------------------------------------
  // Subscribed list
  // ---------------------------------------------------------------------------

  Future<Cached<List<ProjectSummary>>?> readSubscribed(String userId) {
    return _summaryTable.read(
      userId: userId,
      projectId: _subscribedSentinel,
    );
  }

  Future<void> writeSubscribed({
    required String userId,
    required List<ProjectSummary> projects,
    required DateTime fetchedAt,
  }) {
    return _summaryTable.write(
      userId: userId,
      projectId: _subscribedSentinel,
      value: projects,
      fetchedAt: fetchedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Per-project detail
  // ---------------------------------------------------------------------------

  Future<Cached<ProjectDetail>?> readDetail({
    required String userId,
    required String projectId,
  }) {
    return _detailTable.read(userId: userId, projectId: projectId);
  }

  Future<void> writeDetail({
    required String userId,
    required String projectId,
    required ProjectDetail detail,
    required DateTime fetchedAt,
  }) {
    return _detailTable.write(
      userId: userId,
      projectId: projectId,
      value: detail,
      fetchedAt: fetchedAt,
    );
  }

  Future<void> clearForUser(String userId) =>
      _summaryTable.clearForUser(userId);
}

// ---------------------------------------------------------------------------
// JSON codecs (entity ↔ Map). Living in this file keeps the cache layer
// decoupled from the wire DTOs — schema migrations on the cache side
// don't touch network parsing.
// ---------------------------------------------------------------------------

Object _encodeSummaryList(List<ProjectSummary> list) =>
    list.map(_encodeSummary).toList();

Map<String, Object?> _encodeSummary(ProjectSummary p) => {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'available': p.available,
      'imageUrl': p.imageUrl,
      'website': p.website,
      'isSubscribed': p.isSubscribed,
      'userPoints': p.userPoints,
      'userBadgesCount': p.userBadgesCount,
    };

List<ProjectSummary> _decodeSummaryList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<Object?, Object?>>()
      .map(_decodeSummary)
      .toList(growable: false);
}

ProjectSummary _decodeSummary(Map<Object?, Object?> m) {
  return ProjectSummary(
    id: (m['id'] ?? '').toString(),
    name: (m['name'] ?? '').toString(),
    description: (m['description'] ?? '').toString(),
    available: m['available'] == true,
    imageUrl: m['imageUrl']?.toString(),
    website: m['website']?.toString(),
    isSubscribed: m['isSubscribed'] == true,
    userPoints: _asInt(m['userPoints']),
    userBadgesCount: _asInt(m['userBadgesCount']),
  );
}

Object _encodeDetail(ProjectDetail d) => {
      'id': d.id,
      'name': d.name,
      'description': d.description,
      'available': d.available,
      'imageUrl': d.imageUrl,
      'website': d.website,
      'gamificationStrategy': d.gamificationStrategy,
      'recommendationStrategy': d.recommendationStrategy,
      'leaderboardStrategy': d.leaderboardStrategy,
      'badges': d.badges.map(_encodeBadge).toList(),
      'taskTypes': d.taskTypes.map((t) => {'name': t.name, 'description': t.description}).toList(),
      'areas': d.areas.map(_encodeArea).toList(),
      'user': d.user == null ? null : _encodeUserStats(d.user!),
    };

ProjectDetail _decodeDetail(Object? raw) {
  if (raw is! Map) {
    return const ProjectDetail(
      id: '',
      name: '',
      description: '',
      available: false,
    );
  }
  return ProjectDetail(
    id: (raw['id'] ?? '').toString(),
    name: (raw['name'] ?? '').toString(),
    description: (raw['description'] ?? '').toString(),
    available: raw['available'] == true,
    imageUrl: raw['imageUrl']?.toString(),
    website: raw['website']?.toString(),
    gamificationStrategy: raw['gamificationStrategy']?.toString(),
    recommendationStrategy: raw['recommendationStrategy']?.toString(),
    leaderboardStrategy: raw['leaderboardStrategy']?.toString(),
    badges: _decodeBadges(raw['badges']),
    taskTypes: _decodeTaskTypes(raw['taskTypes']),
    areas: _decodeAreas(raw['areas']),
    user: _decodeUserStats(raw['user']),
  );
}

List<TaskType> _decodeTaskTypes(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((m) {
    if (m is String) {
      return TaskType(name: m);
    }
    if (m is Map) {
      final mm = m.map((k, v) => MapEntry(k.toString(), v));
      return TaskType(
        name: (mm['name'] ?? mm['id'] ?? '').toString(),
        description: mm['description']?.toString(),
      );
    }
    return null;
  }).whereType<TaskType>().toList(growable: false);
}

Map<String, Object?> _encodeBadge(ProjectBadge b) => {
      'name': b.name,
      'description': b.description,
      'imageUrl': b.imageUrl,
      'earned': b.earned,
      'previousBadges': b.previousBadges,
    };

List<ProjectBadge> _decodeBadges(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<Object?, Object?>>().map((m) {
    return ProjectBadge(
      name: (m['name'] ?? '').toString(),
      description: m['description']?.toString(),
      imageUrl: m['imageUrl']?.toString(),
      earned: m['earned'] == true,
      previousBadges: _decodeStringList(m['previousBadges']),
    );
  }).toList(growable: false);
}

Map<String, Object?> _encodeArea(ProjectArea a) => {
      'id': a.id,
      'rings': [
        for (final ring in a.rings)
          [
            for (final pt in ring) [pt.latitude, pt.longitude],
          ],
      ],
    };

List<ProjectArea> _decodeAreas(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<Object?, Object?>>().map((m) {
    final ringsRaw = m['rings'];
    final rings = <List<LatLng>>[];
    if (ringsRaw is List) {
      for (final r in ringsRaw) {
        if (r is! List) continue;
        final ring = <LatLng>[];
        for (final pt in r) {
          if (pt is List && pt.length >= 2) {
            final lat = (pt[0] as num).toDouble();
            final lng = (pt[1] as num).toDouble();
            ring.add(LatLng(lat, lng));
          }
        }
        if (ring.isNotEmpty) rings.add(ring);
      }
    }
    return ProjectArea(
      id: (m['id'] ?? '').toString(),
      rings: rings,
    );
  }).toList(growable: false);
}

Map<String, Object?> _encodeUserStats(ProjectUserStats u) => {
      'isSubscribed': u.isSubscribed,
      'points': u.points,
      'badgesEarned': u.badgesEarned,
      'leaderboardRank': u.leaderboardRank,
    };

ProjectUserStats? _decodeUserStats(Object? raw) {
  if (raw is! Map) return null;
  return ProjectUserStats(
    isSubscribed: raw['isSubscribed'] == true,
    points: _asInt(raw['points']),
    badgesEarned: _asInt(raw['badgesEarned']),
    leaderboardRank: raw['leaderboardRank'] is int
        ? raw['leaderboardRank'] as int
        : null,
  );
}

List<String> _decodeStringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
