import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../data/repositories/tasks_repository_impl.dart';
import '../../data/sources/tasks_remote_source.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/repositories/tasks_repository.dart';

final tasksRemoteSourceProvider = Provider<TasksRemoteSource>((ref) {
  return TasksRemoteSource(ref.watch(apiClientProvider));
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepositoryImpl(ref.watch(tasksRemoteSourceProvider));
});

/// Tasks for a single project. The provider family lets us cache per-project.
final projectTasksProvider =
    FutureProvider.autoDispose.family<List<TaskItem>, String>(
  (ref, projectId) async {
    final repo = ref.watch(tasksRepositoryProvider);
    final res = await repo.getTasksForProject(projectId);
    return switch (res) {
      Success<List<TaskItem>>(:final value) => value,
      Failure<List<TaskItem>>(:final error) => throw error,
    };
  },
);
