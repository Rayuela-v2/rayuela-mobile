import '../../../../core/cache/cached_value.dart';
import '../../../../core/error/result.dart';
import '../entities/project_detail.dart';
import '../entities/project_summary.dart';

abstract class ProjectsRepository {
  Future<Result<List<ProjectSummary>>> getSubscribedProjects();
  Future<Result<List<ProjectSummary>>> getPublicProjects();

  /// Fetch the full detail for a single project. Carries the per-user
  /// overlay (subscribed flag, points, earned badges) when present.
  Future<Result<ProjectDetail>> getProjectDetail(String id);

  /// Toggle subscription. Backend infers direction from current state, so
  /// this single call covers both subscribe and unsubscribe.
  Future<Result<void>> toggleSubscription(String projectId);

  /// Stale-while-revalidate variant for the dashboard. Yields the
  /// cached list (if any) immediately, then the fresh remote response.
  /// On a soft network failure with a cache present we re-emit the
  /// cache marked as stale so the UI can render an "offline copy"
  /// banner without losing content.
  Stream<Cached<List<ProjectSummary>>> watchSubscribedProjects();

  /// SWR variant for the project detail screen. Same contract as
  /// [watchSubscribedProjects].
  Stream<Cached<ProjectDetail>> watchProjectDetail(String id);
}
