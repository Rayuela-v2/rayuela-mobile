import '../../../../core/error/result.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../sources/leaderboard_remote_source.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  const LeaderboardRepositoryImpl(this._remote);

  final LeaderboardRemoteSource _remote;

  @override
  Future<Result<Leaderboard>> getLeaderboard(String projectId) async {
    final res = await _remote.fetch(projectId);
    return res.fold(
      onSuccess: (dto) => Success(dto.toEntity()),
      onFailure: Failure<Leaderboard>.new,
    );
  }
}
