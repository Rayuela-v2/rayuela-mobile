/// Aggregated check-in activity for the signed-in volunteer, from
/// `GET /checkin/me/stats`.
///
/// Points and badges are *not* here: those already ride along with each
/// project in `ProjectSummary`, so the profile reads them from the
/// (offline-cached) projects list instead of asking again.
class ProfileStats {
  const ProfileStats({
    required this.totalCheckins,
    required this.streakDays,
    required this.activeDays,
    required this.checkinsByProject,
  });

  static const empty = ProfileStats(
    totalCheckins: 0,
    streakDays: 0,
    activeDays: 0,
    checkinsByProject: {},
  );

  final int totalCheckins;

  /// Consecutive active days ending today or yesterday.
  final int streakDays;

  /// Distinct days with at least one mission.
  final int activeDays;

  /// projectId → missions logged there.
  final Map<String, int> checkinsByProject;

  int checkinsFor(String projectId) => checkinsByProject[projectId] ?? 0;
}
