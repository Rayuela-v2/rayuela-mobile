import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../models/leaderboard_dto.dart';

/// HTTP for the per-project leaderboard. Backend returns the Mongoose
/// document straight from the DAO, so we tolerate either a bare object or
/// a `{ data: {...} }` envelope to match other endpoints.
class LeaderboardRemoteSource {
  const LeaderboardRemoteSource(this._api);

  final ApiClient _api;

  Future<Result<LeaderboardDto>> fetch(String projectId) {
    return _api.request(
      (d) => d.get<dynamic>(ApiPaths.leaderboard(projectId)),
      parse: (raw) =>
          LeaderboardDto.tryParse(raw) ??
          // Empty leaderboard is a legitimate state for a brand-new project
          // — surface a usable, empty entity rather than a parse failure.
          LeaderboardDto(projectId: projectId, users: const []),
    );
  }
}
