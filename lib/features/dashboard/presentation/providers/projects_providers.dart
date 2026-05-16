import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cached_value.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/repositories/projects_repository_impl.dart';
import '../../data/sources/projects_local_source.dart';
import '../../data/sources/projects_remote_source.dart';
import '../../domain/entities/project_summary.dart';
import '../../domain/repositories/projects_repository.dart';

final projectsRemoteSourceProvider = Provider<ProjectsRemoteSource>((ref) {
  return ProjectsRemoteSource(ref.watch(apiClientProvider));
});

/// Local cache for projects (subscribed list + per-project detail).
/// Built off [appDatabaseProvider] so feature code never sees the DB.
final projectsLocalSourceProvider = Provider<ProjectsLocalSource>((ref) {
  return ProjectsLocalSource(ref.watch(appDatabaseProvider).db);
});

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepositoryImpl(
    ref.watch(projectsRemoteSourceProvider),
    local: ref.watch(projectsLocalSourceProvider),
    currentUser: () {
      final state = ref.read(authControllerProvider);
      return state is AuthStateAuthenticated ? state.user : _emptyUser;
    },
  );
});

/// Sentinel used when no user is signed in — repository will fall back to
/// the wire data unchanged.
const AuthUser _emptyUser = AuthUser(
  id: '',
  username: '',
  completeName: '',
  email: '',
  role: UserRole.unknown,
);

/// Stale-while-revalidate stream of the user's subscribed projects.
///
/// Yields:
///   * the cached list immediately (if any) with `isStale: true|false`,
///   * then the fresh list after the network call,
///   * then nothing (stream closes) — pull-to-refresh re-subscribes.
///
/// On a soft network failure the stream emits the cached value marked
/// stale instead of erroring; only hard failures (auth, validation,
/// unknown) propagate as `AsyncError`.
final subscribedProjectsProvider = StreamProvider.autoDispose<
    Cached<List<ProjectSummary>>>((ref) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchSubscribedProjects();
});

/// Convenience view that drops the cache metadata. Use it from screens
/// that don't care whether the data is fresh — most callers can just
/// watch [subscribedProjectsProvider] directly and read `.value` when
/// they need the chip.
final subscribedProjectsValueProvider =
    Provider.autoDispose<AsyncValue<List<ProjectSummary>>>((ref) {
  return ref.watch(subscribedProjectsProvider).whenData((c) => c.value);
});

