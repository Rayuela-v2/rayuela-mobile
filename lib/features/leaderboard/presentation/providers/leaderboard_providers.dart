import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../data/sources/leaderboard_remote_source.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/repositories/leaderboard_repository.dart';

final leaderboardRemoteSourceProvider = Provider<LeaderboardRemoteSource>((ref) {
  return LeaderboardRemoteSource(ref.watch(apiClientProvider));
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepositoryImpl(ref.watch(leaderboardRemoteSourceProvider));
});

/// Per-project leaderboard. Auto-disposing so we drop it when the user
/// leaves the project detail screen — the data is small but mutates after
/// every check-in, so we'd rather refetch than show stale rankings.
final leaderboardProvider = FutureProvider.autoDispose
    .family<Leaderboard, String>((ref, projectId) async {
  final repo = ref.watch(leaderboardRepositoryProvider);
  final res = await repo.getLeaderboard(projectId);
  return switch (res) {
    Success<Leaderboard>(:final value) => value,
    Failure<Leaderboard>(:final error) => throw _toThrowable(error),
  };
});

Object _toThrowable(AppException e) => e;
