import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cached_value.dart';
import '../../../../core/error/result.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/project_detail.dart';
import 'projects_providers.dart';

/// Stale-while-revalidate stream of one project's detail. Auto-disposes
/// when the detail screen pops. Pull-to-refresh invalidates the family
/// entry to re-run the cache + remote pair.
final projectDetailProvider =
    StreamProvider.autoDispose.family<Cached<ProjectDetail>, String>(
  (ref, projectId) {
    final repo = ref.watch(projectsRepositoryProvider);
    return repo.watchProjectDetail(projectId);
  },
);

/// Convenience view: drops the cache metadata for callers that only
/// care about the entity itself.
final projectDetailValueProvider = Provider.autoDispose
    .family<AsyncValue<ProjectDetail>, String>((ref, projectId) {
  return ref.watch(projectDetailProvider(projectId)).whenData((c) => c.value);
});

/// One-shot refresh used by pull-to-refresh handlers. Invalidate the SWR
/// stream and await the first non-stale value so the spinner stays up
/// until the network call returns.
final refreshProjectDetailProvider =
    Provider<Future<void> Function(String)>((ref) {
  return (projectId) async {
    ref.invalidate(projectDetailProvider(projectId));
    await ref.read(projectDetailProvider(projectId).stream).firstWhere(
          (cached) => !cached.isStale,
        );
  };
});

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
