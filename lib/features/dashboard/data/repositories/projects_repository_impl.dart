import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/project_detail.dart';
import '../../domain/entities/project_summary.dart';
import '../../domain/repositories/projects_repository.dart';
import '../models/project_dto.dart';
import '../sources/projects_remote_source.dart';

/// Stitches per-user gamification stats onto each project.
///
/// The backend's `GET /volunteer/projects` returns plain project documents
/// with only a `subscribed: bool` flag — there is no per-project `points`
/// or `badges` field on the response. We overlay those by looking up
/// `currentUser.gameProfileFor(projectId)`. When backend §4.1 ships an
/// enriched response we can drop the overlay and trust the wire shape.
class ProjectsRepositoryImpl implements ProjectsRepository {
  ProjectsRepositoryImpl(
    this._remote, {
    AuthUser Function()? currentUser,
  }) : _currentUser = currentUser;

  final ProjectsRemoteSource _remote;
  final AuthUser Function()? _currentUser;

  @override
  Future<Result<List<ProjectSummary>>> getSubscribedProjects() async {
    final res = await _remote.fetchSubscribedProjects();
    return res.fold(
      onSuccess: (list) => Success(_overlay(list)),
      onFailure: Failure<List<ProjectSummary>>.new,
    );
  }

  @override
  Future<Result<List<ProjectSummary>>> getPublicProjects() async {
    final res = await _remote.fetchPublicProjects();
    return res.fold(
      onSuccess: (list) => Success(_overlay(list)),
      onFailure: Failure<List<ProjectSummary>>.new,
    );
  }

  @override
  Future<Result<ProjectDetail>> getProjectDetail(String id) async {
    final res = await _remote.fetchProjectDetail(id);
    return res.fold(
      onSuccess: (dto) => Success(dto.toEntity()),
      onFailure: Failure<ProjectDetail>.new,
    );
  }

  @override
  Future<Result<void>> toggleSubscription(String projectId) {
    return _remote.toggleSubscription(projectId);
  }

  List<ProjectSummary> _overlay(List<ProjectDto> list) {
    final user = _currentUser?.call();
    if (user == null || user.gameProfiles.isEmpty) {
      return list.map((d) => d.toEntity()).toList(growable: false);
    }
    return list.map((d) {
      final gp = user.gameProfileFor(d.id);
      if (gp == null) return d.toEntity();
      return d
          .withUserStats(points: gp.points, badgesCount: gp.badges.length)
          .toEntity();
    }).toList(growable: false);
  }
}
