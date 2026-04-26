import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/core_providers.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/error/result.dart';
import '../../data/repositories/projects_repository_impl.dart';
import '../../data/sources/projects_remote_source.dart';
import '../../domain/entities/project_summary.dart';
import '../../domain/repositories/projects_repository.dart';

final projectsRemoteSourceProvider = Provider<ProjectsRemoteSource>((ref) {
  return ProjectsRemoteSource(ref.watch(apiClientProvider));
});

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepositoryImpl(
    ref.watch(projectsRemoteSourceProvider),
    currentUser: () {
      final state = ref.read(authControllerProvider);
      return state is AuthStateAuthenticated ? state.user : _emptyUser;
    },
  );
});

/// Sentinel used when no user is signed in — repository will fall back to
/// the wire data unchanged.
final AuthUser _emptyUser = const AuthUser(
  id: '',
  username: '',
  completeName: '',
  email: '',
  role: UserRole.unknown,
);

/// Dashboard feed: projects the current user is subscribed to.
///
/// Throws the typed `AppException` on failure so `AsyncError.error` carries
/// it through to the UI where `ErrorView` pattern-matches.
/// Invalidate via `ref.invalidate(subscribedProjectsProvider)` for pull-to-refresh.
final subscribedProjectsProvider =
    FutureProvider.autoDispose<List<ProjectSummary>>((ref) async {
  final repo = ref.watch(projectsRepositoryProvider);
  final res = await repo.getSubscribedProjects();
  return switch (res) {
    Success<List<ProjectSummary>>(:final value) => value,
    Failure<List<ProjectSummary>>(:final error) => throw error,
  };
});
