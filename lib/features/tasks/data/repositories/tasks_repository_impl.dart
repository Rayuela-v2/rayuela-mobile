import '../../../../core/error/result.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../sources/tasks_remote_source.dart';

class TasksRepositoryImpl implements TasksRepository {
  const TasksRepositoryImpl(this._remote);

  final TasksRemoteSource _remote;

  @override
  Future<Result<List<TaskItem>>> getTasksForProject(String projectId) async {
    final res = await _remote.fetchTasksForProject(projectId);
    return res.fold(
      onSuccess: (list) =>
          Success(list.map((d) => d.toEntity()).toList(growable: false)),
      onFailure: Failure<List<TaskItem>>.new,
    );
  }
}
