import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../data/sources/profile_stats_remote_source.dart';
import '../../domain/entities/profile_stats.dart';

final profileStatsRemoteSourceProvider = Provider<ProfileStatsRemoteSource>(
  (ref) => ProfileStatsRemoteSource(ref.watch(apiClientProvider)),
);

/// Network-only: the numbers are a bonus panel, so offline it just shows a
/// dash instead of dragging in a cache table. Points/badges/projects come
/// from the projects list, which *is* cached, so the section is never empty.
final profileStatsProvider =
    FutureProvider.autoDispose<ProfileStats>((ref) async {
  final res = await ref.watch(profileStatsRemoteSourceProvider).fetchMyStats();
  return switch (res) {
    Success<ProfileStats>(:final value) => value,
    Failure<ProfileStats>(:final error) => throw error,
  };
});
