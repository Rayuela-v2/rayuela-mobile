import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/outbox/outbox_entry.dart';
import '../../../../core/sync/outbox/outbox_service.dart';
import '../../../../core/sync/outbox/sync_status.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

/// Live list of pending check-ins for the currently signed-in user.
///
/// Re-fetches whenever the [OutboxService] reports a row change. The
/// `null` payload that the service emits at the end of a drain cycle
/// also triggers a re-fetch — that's when most rows transition.
///
/// `family<String?>` keys by `projectId`; pass `null` to get the full
/// list across all projects (used by the "Pending data" settings
/// screen).
final pendingCheckinsProvider = StreamProvider.autoDispose
    .family<List<OutboxEntry>, String?>((ref, projectId) async* {
  final service = ref.watch(outboxServiceProvider);
  final dao = ref.watch(outboxDaoProvider);
  final auth = ref.watch(authControllerProvider);
  final userId =
      auth is AuthStateAuthenticated ? auth.user.id : '';
  if (userId.isEmpty) {
    yield const [];
    return;
  }

  Future<List<OutboxEntry>> snapshot() =>
      dao.listForUser(userId, projectId: projectId);

  yield await snapshot();
  await for (final _ in service.changes) {
    yield await snapshot();
  }
});

/// Coarse, app-wide sync status used by the AppBar badge.
///
/// We expose the [OutboxService.statusStream] as a regular Riverpod
/// stream and seed it with the current value so UI doesn't flash
/// "unknown" on first build.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final service = ref.watch(outboxServiceProvider);
  yield service.status;
  yield* service.statusStream;
});

/// How many rows are currently in the queue (excluding `dead`). Drives
/// the "N pending" copy in the dashboard banner.
final pendingCheckinCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final service = ref.watch(outboxServiceProvider);
  final dao = ref.watch(outboxDaoProvider);
  final auth = ref.watch(authControllerProvider);
  final userId =
      auth is AuthStateAuthenticated ? auth.user.id : '';
  if (userId.isEmpty) {
    yield 0;
    return;
  }
  yield await dao.pendingCount(userId);
  await for (final _ in service.changes) {
    yield await dao.pendingCount(userId);
  }
});
