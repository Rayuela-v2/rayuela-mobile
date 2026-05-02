import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/image_store.dart';
import '../../core/storage/secure_token_store.dart';
import '../../core/sync/app_database.dart';
import '../../core/sync/connectivity_service.dart';

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
