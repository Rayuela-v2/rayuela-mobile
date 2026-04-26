import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../data/repositories/checkins_repository_impl.dart';
import '../../data/sources/checkins_remote_source.dart';
import '../../domain/entities/checkin_history_item.dart';
import '../../domain/repositories/checkins_repository.dart';
import '../services/location_service.dart';

final checkinsRemoteSourceProvider = Provider<CheckinsRemoteSource>((ref) {
  return CheckinsRemoteSource(ref.watch(apiClientProvider));
});

final checkinsRepositoryProvider = Provider<CheckinsRepository>((ref) {
  return CheckinsRepositoryImpl(ref.watch(checkinsRemoteSourceProvider));
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
