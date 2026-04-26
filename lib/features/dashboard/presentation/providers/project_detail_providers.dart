import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/project_detail.dart';
import 'projects_providers.dart';

/// Detail for a single project, keyed by projectId. Auto-disposes when the
/// detail screen pops so we don't hold onto leaderboard data nobody is
/// looking at. Pull-to-refresh invalidates the family entry.
final projectDetailProvider =
    FutureProvider.autoDispose.family<ProjectDetail, String>(
  (ref, projectId) async {
    final repo = ref.watch(projectsRepositoryProvider);
    final res = await repo.getProjectDetail(projectId);
    return switch (res) {
      Success<ProjectDetail>(:final value) => value,
      Failure<ProjectDetail>(:final error) => throw error,
    };
  },
);

/// View state for the subscribe button. Tracks in-flight calls so the UI
/// can disable the button + show a spinner without bothering the detail
/// future. We expose a controller class rather than a plain bool so the
/// caller gets a typed `error` after a failure.
sealed class SubscriptionToggleState {
  const SubscriptionToggleState();
}

final class SubscriptionIdle extends SubscriptionToggleState {
  const SubscriptionIdle();
}

final class SubscriptionInFlight extends SubscriptionToggleState {
  const SubscriptionInFlight();
}

final class SubscriptionFailed extends SubscriptionToggleState {
  const SubscriptionFailed(this.message);
  final String message;
}

class SubscriptionToggleController extends StateNotifier<SubscriptionToggleState> {
  SubscriptionToggleController(this._ref) : super(const SubscriptionIdle());

  final Ref _ref;

  /// Toggle subscription for the given project. On success:
  ///   1. Re-fetch the current user (so dashboard cards see new gameProfile).
  ///   2. Invalidate the project detail so the subscribed/unsubscribed
  ///      branch flips on the screen.
  /// Returns true on success, false otherwise. The controller's own state
  /// also reflects the outcome.
  Future<bool> toggle(String projectId) async {
    if (state is SubscriptionInFlight) return false;
    state = const SubscriptionInFlight();

    final repo = _ref.read(projectsRepositoryProvider);
    final res = await repo.toggleSubscription(projectId);

    switch (res) {
      case Success<void>():
        // Refresh auth user first so subsequent provider rebuilds (which
        // depend on gameProfiles) see the updated state. Then invalidate
        // detail + dashboard list.
        await _ref.read(authControllerProvider.notifier).refreshUser();
        _ref.invalidate(projectDetailProvider(projectId));
        _ref.invalidate(subscribedProjectsProvider);
        if (mounted) state = const SubscriptionIdle();
        return true;
      case Failure<void>(:final error):
        if (mounted) state = SubscriptionFailed(error.message);
        return false;
    }
  }
}

final subscriptionToggleControllerProvider = StateNotifierProvider.autoDispose<
    SubscriptionToggleController, SubscriptionToggleState>((ref) {
  return SubscriptionToggleController(ref);
});
