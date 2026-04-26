/// Lightweight project card representation used by the dashboard and the
/// public project discovery list. For the full detail view we'll add a
/// richer entity in phase 1.
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.available,
    this.imageUrl,
    this.website,
    this.isSubscribed = false,
    this.userPoints = 0,
    this.userBadgesCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final bool available;
  final String? imageUrl;
  final String? website;
  final bool isSubscribed;
  final int userPoints;
  final int userBadgesCount;
}
