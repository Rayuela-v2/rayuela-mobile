import '../../../../core/error/result.dart';
import '../entities/leaderboard.dart';

abstract class LeaderboardRepository {
  /// Fetches the per-project ranking, sorted by points desc with ranks
  /// already populated.
  Future<Result<Leaderboard>> getLeaderboard(String projectId);
}
