import '../../../../core/cache/cached_value.dart';
import '../../../../core/cache/stale_while_revalidate.dart';
import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/project_detail.dart';
import '../../domain/entities/project_summary.dart';
import '../../domain/repositories/projects_repository.dart';
import '../models/project_dto.dart';
import '../sources/projects_local_source.dart';
import '../sources/projects_remote_source.dart';

/// Stitches per-user gamification stats onto each project, and now —
/// in Phase 2 — also wraps reads in a stale-while-revalidate layer
/// backed by [ProjectsLocalSource]. The Future-based methods (used by
/// pull-to-refresh and one-shot loads) keep the original write-through
/// behaviour: hit the network, populate the cache, return the result.
///
/// The Stream-based `watchX` methods are the SWR entry points: they
/// emit the cache immediately (if any) and then the fresh value, so a
/// volunteer opening the dashboard offline still sees their projects.
class ProjectsRepositoryImpl implements ProjectsRepository {
  ProjectsRepositoryImpl(
    this._remote, {
    AuthUser Function()? currentUser,
    ProjectsLocalSource? local,
  })  : _currentUser = currentUser,
        _local = local;

  final ProjectsRemoteSource _remote;
  final ProjectsLocalSource? _local;
  final AuthUser Function()? _currentUser;

  @override
  Future<Result<List<ProjectSummary>>> getSubscribedProjects() async {
    final res = await _remote.fetchSubscribedProjects();
    return res.fold(
      onSuccess: (list) async {
        final overlaid = _overlay(list);
        await _writeSubscribedCache(overlaid);
        return Success(overlaid);
      },
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
      onSuccess: (dto) async {
        final detail = dto.toEntity();
        await _writeDetailCache(id, detail);
        return Success(detail);
      },
      onFailure: Failure<ProjectDetail>.new,
    );
  }

  @override
  Future<Result<void>> toggleSubscription(String projectId) {
    return _remote.toggleSubscription(projectId);
  }

  // ---------------------------------------------------------------------------
  // SWR (Phase 2 reads)
  // ---------------------------------------------------------------------------

  @override
  Stream<Cached<List<ProjectSummary>>> watchSubscribedProjects() {
    final userId = _userId();
    final local = _local;

    return staleWhileRevalidate<List<ProjectSummary>>(
      readLocal: () async {
        if (local == null || userId.isEmpty) return null;
        return local.readSubscribed(userId);
      },
      fetchRemote: () async {
        final res = await _remote.fetchSubscribedProjects();
        return switch (res) {
          Success<List<ProjectDto>>(:final value) => _overlay(value),
          Failure<List<ProjectDto>>(:final error) => throw error,
        };
      },
      writeLocal: (value, _) async {
        if (local == null || userId.isEmpty) return;
        await local.writeSubscribed(
          userId: userId,
          projects: value,
          fetchedAt: DateTime.now(),
        );
      },
    );
  }

  @override
  Stream<Cached<ProjectDetail>> watchProjectDetail(String id) {
    final userId = _userId();
    final local = _local;

    return staleWhileRevalidate<ProjectDetail>(
      readLocal: () async {
        if (local == null || userId.isEmpty) return null;
        return local.readDetail(userId: userId, projectId: id);
      },
      fetchRemote: () async {
        final res = await _remote.fetchProjectDetail(id);
        return switch (res) {
          Success(:final value) => value.toEntity(),
          Failure(:final error) => throw error,
        };
      },
      writeLocal: (value, _) async {
        if (local == null || userId.isEmpty) return;
        await local.writeDetail(
          userId: userId,
          projectId: id,
          detail: value,
          fetchedAt: DateTime.now(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

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

  String _userId() => _currentUser?.call().id ?? '';

  Future<void> _writeSubscribedCache(List<ProjectSummary> projects) async {
    final local = _local;
    final userId = _userId();
    if (local == null || userId.isEmpty) return;
    await local.writeSubscribed(
      userId: userId,
      projects: projects,
      fetchedAt: DateTime.now(),
    );
  }

  Future<void> _writeDetailCache(String id, ProjectDetail detail) async {
    final local = _local;
    final userId = _userId();
    if (local == null || userId.isEmpty) return;
    await local.writeDetail(
      userId: userId,
      projectId: id,
      detail: detail,
      fetchedAt: DateTime.now(),
    );
  }
}
