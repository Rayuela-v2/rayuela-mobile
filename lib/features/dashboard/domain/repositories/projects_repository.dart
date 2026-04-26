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
}
