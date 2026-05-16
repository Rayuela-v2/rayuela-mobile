import '../../../../core/cache/cached_value.dart';
import '../../../../core/error/result.dart';
import '../entities/task_item.dart';

abstract class TasksRepository {
  Future<Result<List<TaskItem>>> getTasksForProject(String projectId);

  /// Stale-while-revalidate variant for the project-detail Tasks tab.
  /// Yields cache → fresh → cache-as-stale on a soft network failure.
  Stream<Cached<List<TaskItem>>> watchTasksForProject(String projectId);
}
