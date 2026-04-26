import '../../../../core/error/result.dart';
import '../entities/task_item.dart';

abstract class TasksRepository {
  Future<Result<List<TaskItem>>> getTasksForProject(String projectId);
}
