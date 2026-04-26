import 'project_area.dart';

/// Rich domain representation of a single project. Returned by
/// `GET /projects/:id`. Carries enough data to drive the project detail
/// screen — header, gamification config, and (when subscribed) the
/// per-user overlay.
///
/// Compared to [ProjectSummary] (used on the dashboard cards), this adds:
///   * gamification & strategy metadata (badges, point ranges, strategies)
///   * the optional [user] block — points, earned badges, leaderboard rank
///   * the project's [areas] (GeoJSON polygons) used by the Overview map
///
/// The web app's ProjectView pulls leaderboard, tasks and check-ins as
/// separate calls. We mirror that pattern, so this entity intentionally
/// does NOT carry the leaderboard/tasks/checkins lists — each comes from
/// its own provider.
class ProjectDetail {
  const ProjectDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.available,
    this.imageUrl,
    this.website,
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
  final String? imageUrl;
  final String? website;

  /// One of `BASIC` / `ELASTIC`. Display-only on mobile; the web admin
  /// configures the value, mobile just shows a chip.
  final String? gamificationStrategy;

  /// One of `SIMPLE` / `ADAPTIVE`.
  final String? recommendationStrategy;

  /// One of `POINTS_FIRST` / `BADGES_FIRST`.
  final String? leaderboardStrategy;

  /// Catalog of badges this project awards. When [user] is non-null each
  /// badge's `earned` flag reflects the current user's progress.
  final List<ProjectBadge> badges;

  /// Free-text labels the project lets check-ins use (e.g. "Observation",
  /// "Photo report"). Populated from project.taskTypes if backend exposes it.
  final List<String> taskTypes;

  /// GeoJSON polygons defining the project's working areas. Drives the
  /// Overview map; empty when the project hasn't been geo-configured.
  final List<ProjectArea> areas;

  /// Per-user overlay. `null` means the user is not subscribed (or has no
  /// game profile yet).
  final ProjectUserStats? user;

  bool get isSubscribed => user?.isSubscribed ?? false;

  ProjectDetail copyWith({ProjectUserStats? user}) {
    return ProjectDetail(
      id: id,
      name: name,
      description: description,
      available: available,
      imageUrl: imageUrl,
      website: website,
      gamificationStrategy: gamificationStrategy,
      recommendationStrategy: recommendationStrategy,
      leaderboardStrategy: leaderboardStrategy,
      badges: badges,
      taskTypes: taskTypes,
      areas: areas,
      user: user ?? this.user,
    );
  }
}

class ProjectBadge {
  const ProjectBadge({
    required this.name,
    this.description,
    this.imageUrl,
    this.earned = false,
    this.previousBadges = const [],
  });

  final String name;
  final String? description;
  final String? imageUrl;

  /// True when the current user has earned this badge.
  final bool earned;

  /// Names of the badges that must be earned before this one becomes
  /// achievable. Drives the dependency-graph view (Sugiyama-style DAG).
  /// Backend field: `BadgeRule.previousBadges: string[]`.
  final List<String> previousBadges;

  ProjectBadge copyWith({bool? earned}) => ProjectBadge(
        name: name,
        description: description,
        imageUrl: imageUrl,
        earned: earned ?? this.earned,
        previousBadges: previousBadges,
      );
}

class ProjectUserStats {
  const ProjectUserStats({
    required this.isSubscribed,
    this.points = 0,
    this.badgesEarned = 0,
    this.leaderboardRank,
  });

  final bool isSubscribed;
  final int points;
  final int badgesEarned;

  /// 1-based rank within the project's leaderboard. Null when the leaderboard
  /// hasn't been computed yet or the user has no points.
  final int? leaderboardRank;
}
