import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cached_value.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/repositories/tasks_repository_impl.dart';
import '../../data/sources/tasks_local_source.dart';
import '../../data/sources/tasks_remote_source.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/repositories/tasks_repository.dart';

final tasksRemoteSourceProvider = Provider<TasksRemoteSource>((ref) {
  return TasksRemoteSource(ref.watch(apiClientProvider));
});

final tasksLocalSourceProvider = Provider<TasksLocalSource>((ref) {
  return TasksLocalSource(ref.watch(appDatabaseProvider).db);
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepositoryImpl(
    ref.watch(tasksRemoteSourceProvider),
    local: ref.watch(tasksLocalSourceProvider),
    currentUserId: () {
      final state = ref.read(authControllerProvider);
      return state is AuthStateAuthenticated ? state.user.id : '';
    },
  );
});

/// SWR stream for the project's tasks. Family is keyed by `projectId`
/// so each open project keeps its own cache lifecycle.
final projectTasksProvider =
    StreamProvider.autoDispose.family<Cached<List<TaskItem>>, String>(
  (ref, projectId) {
    final repo = ref.watch(tasksRepositoryProvider);
    return repo.watchTasksForProject(projectId);
  },
);

/// Convenience: the entity list without the cache metadata, for screens
/// that just want a `List<TaskItem>`.
final projectTasksValueProvider = Provider.autoDispose
    .family<AsyncValue<List<TaskItem>>, String>((ref, projectId) {
  return ref.watch(projectTasksProvider(projectId)).whenData((c) => c.value);
});
