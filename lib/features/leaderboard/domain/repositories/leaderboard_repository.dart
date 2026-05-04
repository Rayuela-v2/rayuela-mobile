import '../../../../core/cache/cached_value.dart';
import '../../../../core/error/result.dart';
import '../entities/leaderboard.dart';

abstract class LeaderboardRepository {
  /// Fetches the per-project ranking, sorted by points desc with ranks
  /// already populated.
  Future<Result<Leaderboard>> getLeaderboard(String projectId);

  /// SWR variant: cache → fresh → cache-as-stale on a soft network
  /// failure. The leaderboard tab in the project detail uses this.
  Stream<Cached<Leaderboard>> watchLeaderboard(String projectId);
}
