import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../models/project_detail_dto.dart';
import '../models/project_dto.dart';

class ProjectsRemoteSource {
  const ProjectsRemoteSource(this._api);

  final ApiClient _api;

  /// GET /volunteer/projects — user-specific list of subscribed projects,
  /// enriched with per-user points and badge count.
  Future<Result<List<ProjectDto>>> fetchSubscribedProjects() {
    return _api.request(
      (d) => d.get<List<dynamic>>(ApiPaths.volunteerProjects),
      parse: _parseList,
    );
  }

  /// GET /volunteer/public/projects — public project directory.
  Future<Result<List<ProjectDto>>> fetchPublicProjects() {
    return _api.request(
      (d) => d.get<List<dynamic>>(ApiPaths.volunteerPublicProjects),
      parse: _parseList,
    );
  }

  /// GET /projects/:id — full project payload, with the per-user `user`
  /// overlay grafted on by the backend when the JWT subject has a game
  /// profile for this project. Unsubscribed users get the bare project.
  Future<Result<ProjectDetailDto>> fetchProjectDetail(String id) {
    return _api.request(
      (d) => d.get<Map<String, dynamic>>(ApiPaths.project(id)),
      parse: ProjectDetailDto.fromJson,
    );
  }

  /// POST /volunteer/subscription/:id — backend toggles subscription:
  /// not subscribed → subscribed, subscribed → unsubscribed. Returns the
  /// updated User document. We don't need to parse it (the caller refetches
  /// the project detail and the auth user) but we do confirm the call
  /// succeeded.
  Future<Result<void>> toggleSubscription(String projectId) {
    return _api.request(
      (d) => d.post<Object?>(ApiPaths.subscribe(projectId)),
      parse: (_) {},
    );
  }

  List<ProjectDto> _parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProjectDto.fromJson)
        .toList(growable: false);
  }
}
