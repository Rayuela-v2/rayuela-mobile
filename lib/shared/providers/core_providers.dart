import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/image_store.dart';
import '../../core/storage/secure_token_store.dart';
import '../../core/sync/app_database.dart';
import '../../core/sync/connectivity_service.dart';
import '../../core/sync/outbox/outbox_dao.dart';
import '../../core/sync/outbox/outbox_lifecycle.dart';
import '../../core/sync/outbox/outbox_service.dart';

/// Root providers shared across features. Overridden in `main.dart` so the
/// app can wire real implementations without touching feature code.
///
/// Note: [sharedPreferencesProvider] lives in `core/locale/locale_controller.dart`
/// for historical reasons — feature code that needs prefs imports it from
/// there, not here, to avoid a circular re-export.
final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

// ---------------------------------------------------------------------------
// Phase 2 — offline & sync foundations
// ---------------------------------------------------------------------------

/// Local SQLite database (outbox + read caches). Opened once during
/// bootstrap and overridden into the container so feature code can read
/// it via the [Provider] without thinking about lifecycle.
///
/// Closing is handled by the bootstrap shutdown hook; we don't tie the
/// close to provider disposal because the database is meant to live for
/// the entire app session.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

/// Persists pending check-in attachments to the app's private support
/// directory. See [ImageStore] for the on-disk layout.
final imageStoreProvider = Provider<ImageStore>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

/// Reactive view over the device's network state, layered with a
/// reachability probe so the outbox drainer can distinguish "interface
/// up" from "backend reachable".
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

/// DAO over the SQLite outbox tables. Built on top of [appDatabaseProvider]
/// so feature code never has to know which table a row lives in.
final outboxDaoProvider = Provider<OutboxDao>((ref) {
  return OutboxDao(ref.watch(appDatabaseProvider).db);
});

/// Orchestrator for the offline check-in queue: enqueue, drain, retry,
/// discard. Wired in `bootstrap.dart` so its [OutboxSender] dependency
/// (which lives in `features/checkin/`) can be plugged in without
/// `core/` knowing about it.
final outboxServiceProvider = Provider<OutboxService>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

/// Listener that turns OS lifecycle + connectivity events into
/// `outboxService.drain(...)` calls. Sprint B wires this in bootstrap;
/// the auth controller calls `bind(userId)` after login and `unbind()`
/// on sign-out.
final outboxLifecycleProvider = Provider<OutboxLifecycle>((ref) {
  throw UnimplementedError('Override in bootstrap');
});
