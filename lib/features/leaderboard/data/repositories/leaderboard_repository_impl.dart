import '../../../../core/cache/cached_value.dart';
import '../../../../core/cache/stale_while_revalidate.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../sources/leaderboard_local_source.dart';
import '../sources/leaderboard_remote_source.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  LeaderboardRepositoryImpl(
    this._remote, {
    LeaderboardLocalSource? local,
    String Function()? currentUserId,
  })  : _local = local,
        _currentUserId = currentUserId;

  final LeaderboardRemoteSource _remote;
  final LeaderboardLocalSource? _local;
  final String Function()? _currentUserId;

  @override
  Future<Result<Leaderboard>> getLeaderboard(String projectId) async {
    final res = await _remote.fetch(projectId);
    return res.fold(
      onSuccess: (dto) async {
        final entity = dto.toEntity();
        await _writeCache(projectId, entity);
        return Success(entity);
      },
      onFailure: Failure<Leaderboard>.new,
    );
  }

  @override
  Stream<Cached<Leaderboard>> watchLeaderboard(String projectId) {
    final userId = _userId();
    final local = _local;

    return staleWhileRevalidate<Leaderboard>(
      readLocal: () async {
        if (local == null || userId.isEmpty) return null;
        return local.read(userId: userId, projectId: projectId);
      },
      fetchRemote: () async {
        final res = await _remote.fetch(projectId);
        return switch (res) {
          Success(:final value) => value.toEntity(),
          Failure(:final error) => throw error,
        };
      },
      writeLocal: (value, _) async {
        if (local == null || userId.isEmpty) return;
        await local.write(
          userId: userId,
          projectId: projectId,
          leaderboard: value,
          fetchedAt: DateTime.now(),
        );
      },
    );
  }

  String _userId() => _currentUserId?.call() ?? '';

  Future<void> _writeCache(String projectId, Leaderboard l) async {
    final local = _local;
    final userId = _userId();
    if (local == null || userId.isEmpty) return;
    await local.write(
      userId: userId,
      projectId: projectId,
      leaderboard: l,
      fetchedAt: DateTime.now(),
    );
  }
}
