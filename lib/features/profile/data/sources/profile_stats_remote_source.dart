import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../domain/entities/profile_stats.dart';

/// `GET /checkin/me/stats`. Hand-parsed and forgiving: a missing or
/// malformed field degrades to zero rather than blanking the whole screen.
class ProfileStatsRemoteSource {
  const ProfileStatsRemoteSource(this._api);

  final ApiClient _api;

  Future<Result<ProfileStats>> fetchMyStats() {
    return _api.request(
      (d) => d.get<Map<String, dynamic>>(ApiPaths.myCheckinStats),
      parse: parseProfileStats,
    );
  }
}

/// Top-level (not private) so the wire-shape contract is unit-testable
/// without standing up a Dio client.
ProfileStats parseProfileStats(Object? raw) {
  if (raw is! Map) return ProfileStats.empty;
  final byProject = <String, int>{};
  final list = raw['byProject'];
  if (list is List) {
    for (final item in list) {
      if (item is! Map) continue;
      final id = item['projectId']?.toString();
      if (id == null || id.isEmpty) continue;
      byProject[id] = _asInt(item['count']);
    }
  }
  return ProfileStats(
    totalCheckins: _asInt(raw['total']),
    streakDays: _asInt(raw['streakDays']),
    activeDays: _asInt(raw['activeDays']),
    checkinsByProject: byProject,
  );
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
