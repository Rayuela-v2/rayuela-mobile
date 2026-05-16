import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cached_value.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../data/sources/leaderboard_local_source.dart';
import '../../data/sources/leaderboard_remote_source.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/repositories/leaderboard_repository.dart';

final leaderboardRemoteSourceProvider = Provider<LeaderboardRemoteSource>((ref) {
  return LeaderboardRemoteSource(ref.watch(apiClientProvider));
});

final leaderboardLocalSourceProvider = Provider<LeaderboardLocalSource>((ref) {
  return LeaderboardLocalSource(ref.watch(appDatabaseProvider).db);
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepositoryImpl(
    ref.watch(leaderboardRemoteSourceProvider),
    local: ref.watch(leaderboardLocalSourceProvider),
    currentUserId: () {
      final state = ref.read(authControllerProvider);
      return state is AuthStateAuthenticated ? state.user.id : '';
    },
  );
});

/// SWR stream of the per-project leaderboard. Auto-disposes when the
/// user leaves the project detail screen — the data is small but
/// mutates after every check-in, so we still refresh the live copy on
/// every screen open.
final leaderboardProvider = StreamProvider.autoDispose
    .family<Cached<Leaderboard>, String>((ref, projectId) {
  final repo = ref.watch(leaderboardRepositoryProvider);
  return repo.watchLeaderboard(projectId);
});

/// Convenience: drops the cache metadata for screens that only care
/// about the [Leaderboard] entity.
final leaderboardValueProvider = Provider.autoDispose
    .family<AsyncValue<Leaderboard>, String>((ref, projectId) {
  return ref.watch(leaderboardProvider(projectId)).whenData((c) => c.value);
});
