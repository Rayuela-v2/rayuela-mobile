import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../models/task_dto.dart';

class TasksRemoteSource {
  const TasksRemoteSource(this._api);

  final ApiClient _api;

  /// GET /task/project/:projectId — auth required.
  Future<Result<List<TaskDto>>> fetchTasksForProject(String projectId) {
    return _api.request(
      (d) => d.get<List<dynamic>>(ApiPaths.projectTasks(projectId)),
      parse: _parseList,
    );
  }

  List<TaskDto> _parseList(Object? raw) {
    if (raw is! List) return const [];
    final out = <TaskDto>[];
    for (final item in raw) {
      try {
        out.add(TaskDto.fromJson(item));
      } catch (_) {
        // Skip malformed rows; the rest of the list still renders.
      }
    }
    return out;
  }
}
