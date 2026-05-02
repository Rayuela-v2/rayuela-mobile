import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/repositories/checkins_repository_impl.dart';
import '../../data/sources/checkin_outbox_sender.dart';
import '../../data/sources/checkins_remote_source.dart';
import '../../domain/entities/checkin_history_item.dart';
import '../../domain/repositories/checkins_repository.dart';
import '../services/location_service.dart';

final checkinsRemoteSourceProvider = Provider<CheckinsRemoteSource>((ref) {
  return CheckinsRemoteSource(ref.watch(apiClientProvider));
});

/// Bridge from the generic outbox to the check-in feature: knows how to
/// translate one [OutboxEntry] into a `POST /checkin` call. Held in this
/// file (rather than in `core/`) so the dependency arrow stays
/// `features → core`.
final checkinOutboxSenderProvider = Provider<CheckinOutboxSender>((ref) {
  return CheckinOutboxSender(ref.watch(checkinsRemoteSourceProvider));
});

final checkinsRepositoryProvider = Provider<CheckinsRepository>((ref) {
  return CheckinsRepositoryImpl(
    remote: ref.watch(checkinsRemoteSourceProvider),
    outbox: ref.watch(outboxServiceProvider),
    outboxDao: ref.watch(outboxDaoProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    currentUserId: () {
      final state = ref.read(authControllerProvider);
      return state is AuthStateAuthenticated ? state.user.id : '';
    },
  );
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

/// History of the requesting user's check-ins for a single project, most
/// recent first. Auto-disposes when the project detail screen is dismissed
/// so we don't keep stale data around. Invalidate after a successful POST
/// /checkin to surface the new entry without a manual pull-to-refresh.
final userCheckinsProvider = FutureProvider.autoDispose
    .family<List<CheckinHistoryItem>, String>((ref, projectId) async {
  final repo = ref.watch(checkinsRepositoryProvider);
  final res = await repo.getUserCheckins(projectId);
  return switch (res) {
    Success<List<CheckinHistoryItem>>(:final value) => value,
    Failure<List<CheckinHistoryItem>>(:final error) =>
      throw _toThrowable(error),
  };
});

/// Riverpod's FutureProvider expects an Object thrown on error. We already
/// have AppException, so just rethrow it — it preserves the original cause.
Object _toThrowable(AppException e) => e;
