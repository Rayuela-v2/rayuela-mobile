import 'package:latlong2/latlong.dart';

import '../../domain/entities/project_area.dart';
import '../../domain/entities/project_detail.dart';

/// Wire shape of `GET /projects/:id`.
///
/// The backend (project.service.ts:findOne) spreads the project document
/// and grafts a `user` block on top — but only when the requesting user
/// has a game profile for that project. So:
///
///   subscribed user →
///     {
///       _id, name, description, image, web,
///       gamification: { strategy, badgesRules: [{ name, description, image, active }] },
///       gamificationStrategy, recommendationStrategy, leaderboardStrategy,
///       taskTypes: [...],
///       user: {
///         isSubscribed: boolean,
///         badges: BadgeRule[],   // each with .active
///         points: number,
///         leaderboard: { users: [{userId, points, badges, position}, ...] }
///       }
///     }
///
///   unsubscribed user → same shape WITHOUT the `user` field.
///
/// The Project entity uses ES2022 #-fields with a clean toJSON, but the
/// nested User leak we've seen elsewhere can show up here too if backend
/// changes. We parse defensively against both spellings.
class ProjectDetailDto {
  const ProjectDetailDto({
    required this.id,
    required this.name,
    required this.description,
    required this.available,
    this.image,
    this.web,
    this.gamificationStrategy,
    this.recommendationStrategy,
    this.leaderboardStrategy,
    this.badges = const [],
    this.taskTypes = const [],
    this.areas = const [],
    this.user,
  });

  final String id;
  final String name;
  final String description;
  final bool available;
  final String? image;
  final String? web;
  final String? gamificationStrategy;
  final String? recommendationStrategy;
  final String? leaderboardStrategy;
  final List<ProjectBadgeDto> badges;
  final List<String> taskTypes;
  final List<ProjectAreaDto> areas;
  final ProjectUserStatsDto? user;

  factory ProjectDetailDto.fromJson(Object? raw) {
    final json = _asMap(raw);

    // Badges live under `gamification.badgesRules` on Project entities, but
    // when subscribed the backend ALSO exposes them under `user.badges`
    // (with each one carrying `active: bool`). The user-stitched list is
    // authoritative for the `earned` flag; the catalog is authoritative for
    // metadata (image, description, previousBadges). Merge by name so the
    // dependency graph and locked-badge artwork still render for subscribed
    // users.
    final user = ProjectUserStatsDto.tryParse(json['user']);

    final gamification = _asMap(json['gamification']);
    final catalogRaw = gamification['badgesRules'];
    final catalog = catalogRaw is List
        ? catalogRaw
            .map(ProjectBadgeDto.tryParse)
            .whereType<ProjectBadgeDto>()
            .toList(growable: false)
        : const <ProjectBadgeDto>[];

    final userBadgesRaw = user?.badgesRaw;
    final userBadges = userBadgesRaw is List
        ? userBadgesRaw
            .map(ProjectBadgeDto.tryParse)
            .whereType<ProjectBadgeDto>()
            .toList(growable: false)
        : const <ProjectBadgeDto>[];

    final badges = _mergeBadges(catalog: catalog, userOverlay: userBadges);

    final taskTypesRaw = json['taskTypes'];
    final taskTypes = taskTypesRaw is List
        ? taskTypesRaw
            .map(_taskTypeName)
            .whereType<String>()
            .toList(growable: false)
        : const <String>[];

    // `areas` is a GeoJSON FeatureCollection. We tolerate the field being
    // absent (older projects), an empty FeatureCollection, or a bare list
    // of features (some admin tooling spits this out).
    final areas = ProjectAreaDto.parseFeatureCollection(json['areas']);

    return ProjectDetailDto(
      id: _firstString(json, const ['_id', 'id']) ?? '',
      name: _firstString(json, const ['name']) ?? '',
      description: _firstString(json, const ['description']) ?? '',
      available: _asBool(json['available']) ?? true,
      image: _firstString(json, const ['image']),
      web: _firstString(json, const ['web', 'website']),
      gamificationStrategy: _firstString(
        json,
        const ['gamificationStrategy'],
      ) ??
          _firstString(gamification, const ['strategy']),
      recommendationStrategy:
          _firstString(json, const ['recommendationStrategy']),
      leaderboardStrategy:
          _firstString(json, const ['leaderboardStrategy']),
      badges: badges,
      taskTypes: taskTypes,
      areas: areas,
      user: user,
    );
  }

  ProjectDetail toEntity() {
    return ProjectDetail(
      id: id,
      name: name,
      description: description,
      available: available,
      imageUrl: image,
      website: web,
      gamificationStrategy: gamificationStrategy,
      recommendationStrategy: recommendationStrategy,
      leaderboardStrategy: leaderboardStrategy,
      badges: badges.map((b) => b.toEntity()).toList(growable: false),
      taskTypes: taskTypes,
      areas: areas.map((a) => a.toEntity()).toList(growable: false),
      user: user?.toEntity(),
    );
  }

  static String? _taskTypeName(Object? raw) {
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is Map) {
      final m = raw.map((k, v) => MapEntry(k.toString(), v));
      return _firstString(m, const ['name', 'label']);
    }
    return null;
  }
}

class ProjectBadgeDto {
  const ProjectBadgeDto({
    required this.name,
    this.description,
    this.image,
    this.earned = false,
    this.previousBadges = const [],
  });

  final String name;
  final String? description;
  final String? image;
  final bool earned;
  final List<String> previousBadges;

  static ProjectBadgeDto? tryParse(Object? raw) {
    if (raw is String) {
      if (raw.isEmpty) return null;
      return ProjectBadgeDto(name: raw);
    }
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final name = _firstString(m, const ['name', '_name']);
    if (name == null || name.isEmpty) return null;

    final prevRaw = m['previousBadges'] ?? m['_previousBadges'];
    final previous = prevRaw is List
        ? prevRaw
            .map((e) {
              if (e is String) return e.isEmpty ? null : e;
              if (e is Map) {
                final mm = e.map((k, v) => MapEntry(k.toString(), v));
                return _firstString(mm, const ['name', '_name']);
              }
              return null;
            })
            .whereType<String>()
            .toList(growable: false)
        : const <String>[];

    return ProjectBadgeDto(
      name: name,
      description: _firstString(m, const ['description', '_description']),
      // Backend's BadgeRule entity exposes `imageUrl` (gamification.entity.ts);
      // older builds + admin uploads sometimes spell it `image`. Take both.
      image: _firstString(
        m,
        const ['imageUrl', '_imageUrl', 'image', '_image'],
      ),
      earned: _asBool(m['active'] ?? m['earned']) ?? false,
      previousBadges: previous,
    );
  }

  ProjectBadge toEntity() => ProjectBadge(
        name: name,
        description: description,
        imageUrl: image,
        earned: earned,
        previousBadges: previousBadges,
      );
}

class ProjectUserStatsDto {
  const ProjectUserStatsDto({
    required this.isSubscribed,
    this.points = 0,
    this.leaderboardRank,
    this.badgesRaw,
  });

  final bool isSubscribed;
  final int points;
  final int? leaderboardRank;

  /// Kept around so [ProjectDetailDto] can use the user-stitched badge list
  /// (which carries `active: bool`) when present.
  final Object? badgesRaw;

  static ProjectUserStatsDto? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final isSubscribed = _asBool(m['isSubscribed']) ?? true;
    final points = _asInt(m['points']) ?? 0;

    // `leaderboard` shape: { users: [{userId, points, position}, ...] }.
    // We don't carry the full list here — just compute the user's rank if
    // backend supplies a flat `position`. Otherwise leave null and let the
    // dedicated leaderboard provider handle ranking.
    int? rank;
    final lb = m['leaderboard'];
    if (lb is Map) {
      final lbm = lb.map((k, v) => MapEntry(k.toString(), v));
      rank = _asInt(lbm['position']) ?? _asInt(lbm['rank']);
    } else if (lb is num) {
      rank = lb.toInt();
    }

    return ProjectUserStatsDto(
      isSubscribed: isSubscribed,
      points: points,
      leaderboardRank: rank,
      badgesRaw: m['badges'],
    );
  }

  /// Number of earned badges, computed from the raw badge list.
  int get badgesEarned {
    final raw = badgesRaw;
    if (raw is! List) return 0;
    return raw.where((b) {
      if (b is Map) {
        final m = b.map((k, v) => MapEntry(k.toString(), v));
        return _asBool(m['active'] ?? m['earned']) ?? false;
      }
      return false;
    }).length;
  }

  ProjectUserStats toEntity() => ProjectUserStats(
        isSubscribed: isSubscribed,
        points: points,
        badgesEarned: badgesEarned,
        leaderboardRank: leaderboardRank,
      );
}

// ---------------------------------------------------------------------------
// Badge merging
// ---------------------------------------------------------------------------

/// Combines the project's badge catalog with the per-user overlay so the
/// resulting list has both metadata (image, description, dependency edges)
/// and the user's earned-state. Lookup is by badge name (the same key the
/// frontend graph uses).
///
/// When the user has no overlay we just return the catalog. When the catalog
/// is empty (some legacy projects) we fall back to whatever the overlay
/// provides — better something than nothing on the UI.
List<ProjectBadgeDto> _mergeBadges({
  required List<ProjectBadgeDto> catalog,
  required List<ProjectBadgeDto> userOverlay,
}) {
  if (userOverlay.isEmpty) return catalog;
  if (catalog.isEmpty) return userOverlay;

  final overlayByName = <String, ProjectBadgeDto>{
    for (final b in userOverlay) b.name: b,
  };

  return catalog.map((c) {
    final overlay = overlayByName[c.name];
    if (overlay == null) return c;
    return ProjectBadgeDto(
      name: c.name,
      // Prefer overlay text when set (e.g. localized), else catalog.
      description: overlay.description ?? c.description,
      image: overlay.image ?? c.image,
      earned: overlay.earned,
      // Dependencies live in the catalog only.
      previousBadges: c.previousBadges.isNotEmpty
          ? c.previousBadges
          : overlay.previousBadges,
    );
  }).toList(growable: false);
}

// ---------------------------------------------------------------------------
// Areas (GeoJSON FeatureCollection)
// ---------------------------------------------------------------------------

/// Parses one Feature out of a GeoJSON `FeatureCollection`. Handles both
/// `Polygon` and `MultiPolygon` geometries; holes are dropped (no project
/// uses them today, and dropping them keeps polygon rendering simple).
class ProjectAreaDto {
  const ProjectAreaDto({required this.id, required this.rings});

  final String id;
  final List<List<LatLng>> rings;

  static List<ProjectAreaDto> parseFeatureCollection(Object? raw) {
    // FeatureCollection: { type: 'FeatureCollection', features: [...] }
    // Some endpoints return a bare List<Feature>; tolerate both.
    final features = switch (raw) {
      final Map<String, dynamic> m when m['features'] is List => m['features'] as List,
      final List<dynamic> l => l,
      _ => const <dynamic>[],
    };
    return features
        .map(ProjectAreaDto.tryParseFeature)
        .whereType<ProjectAreaDto>()
        .toList(growable: false);
  }

  /// Returns null when the feature is malformed (missing id, unsupported
  /// geometry, etc.) — better to drop one bad area than fail the whole
  /// project load.
  static ProjectAreaDto? tryParseFeature(Object? raw) {
    if (raw is! Map) return null;
    final feature = raw.map((k, v) => MapEntry(k.toString(), v));

    final props = _asMap(feature['properties']);
    final id = _firstString(props, const ['id', 'name']);
    if (id == null || id.isEmpty) return null;

    final geometry = _asMap(feature['geometry']);
    final type = _firstString(geometry, const ['type']);
    final coords = geometry['coordinates'];
    final rings = <List<LatLng>>[];

    switch (type) {
      case 'Polygon':
        // coordinates: [ outer, hole1, hole2, ... ] — each ring is a list
        // of [lon, lat] pairs. We keep only the outer ring (index 0).
        if (coords is List && coords.isNotEmpty) {
          final outer = _ringFromCoords(coords.first);
          if (outer.isNotEmpty) rings.add(outer);
        }
        break;
      case 'MultiPolygon':
        // coordinates: [ polygon1, polygon2, ... ] — each polygon is a
        // [outer, hole1, ...] list. Keep one ring per polygon.
        if (coords is List) {
          for (final poly in coords) {
            if (poly is List && poly.isNotEmpty) {
              final outer = _ringFromCoords(poly.first);
              if (outer.isNotEmpty) rings.add(outer);
            }
          }
        }
        break;
      default:
        return null; // unsupported geometry (Point/LineString/etc.)
    }
    if (rings.isEmpty) return null;

    return ProjectAreaDto(id: id, rings: rings);
  }

  ProjectArea toEntity() => ProjectArea(id: id, rings: rings);

  /// Coordinates come in as `[[lon, lat], ...]`. Defends against scalar
  /// noise (numbers shipped as strings, missing pairs, etc.).
  static List<LatLng> _ringFromCoords(Object? raw) {
    if (raw is! List) return const <LatLng>[];
    final out = <LatLng>[];
    for (final pair in raw) {
      if (pair is! List || pair.length < 2) continue;
      final lon = _asDouble(pair[0]);
      final lat = _asDouble(pair[1]);
      if (lon == null || lat == null) continue;
      out.add(LatLng(lat, lon));
    }
    return out;
  }
}

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
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
