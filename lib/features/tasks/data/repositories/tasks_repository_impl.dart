import '../../../../core/cache/cached_value.dart';
import '../../../../core/cache/stale_while_revalidate.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../sources/tasks_local_source.dart';
import '../sources/tasks_remote_source.dart';

class TasksRepositoryImpl implements TasksRepository {
  TasksRepositoryImpl(
    this._remote, {
    TasksLocalSource? local,
    String Function()? currentUserId,
  })  : _local = local,
        _currentUserId = currentUserId;

  final TasksRemoteSource _remote;
  final TasksLocalSource? _local;
  final String Function()? _currentUserId;

  @override
  Future<Result<List<TaskItem>>> getTasksForProject(String projectId) async {
    final res = await _remote.fetchTasksForProject(projectId);
    return res.fold(
      onSuccess: (list) async {
        final tasks = list.map((d) => d.toEntity()).toList(growable: false);
        await _writeCache(projectId, tasks);
        return Success(tasks);
      },
      onFailure: Failure<List<TaskItem>>.new,
    );
  }

  @override
  Stream<Cached<List<TaskItem>>> watchTasksForProject(String projectId) {
    final userId = _userId();
    final local = _local;

    return staleWhileRevalidate<List<TaskItem>>(
      readLocal: () async {
        if (local == null || userId.isEmpty) return null;
        return local.read(userId: userId, projectId: projectId);
      },
      fetchRemote: () async {
        final res = await _remote.fetchTasksForProject(projectId);
        return switch (res) {
          Success(:final value) =>
            value.map((d) => d.toEntity()).toList(growable: false),
          Failure(:final error) => throw error,
        };
      },
      writeLocal: (value, _) async {
        if (local == null || userId.isEmpty) return;
        await local.write(
          userId: userId,
          projectId: projectId,
          tasks: value,
          fetchedAt: DateTime.now(),
        );
      },
    );
  }

  String _userId() => _currentUserId?.call() ?? '';

  Future<void> _writeCache(String projectId, List<TaskItem> tasks) async {
    final local = _local;
    final userId = _userId();
    if (local == null || userId.isEmpty) return;
    await local.write(
      userId: userId,
      projectId: projectId,
      tasks: tasks,
      fetchedAt: DateTime.now(),
    );
  }
}
