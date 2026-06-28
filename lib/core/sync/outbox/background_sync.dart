import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../../features/checkin/data/sources/checkin_outbox_sender.dart';
import '../../../features/checkin/data/sources/checkins_remote_source.dart';
import '../../network/api_client.dart';
import '../../storage/image_store.dart';
import '../../storage/secure_token_store.dart';
import '../app_database.dart';
import '../connectivity_service.dart';
import 'outbox_dao.dart';
import 'outbox_service.dart';

/// Top-level entry point hooked to `Workmanager().initialize(...)` at
/// bootstrap time. The platform spawns a fresh background isolate and
/// invokes this function — so it has NO access to the main isolate's
/// Riverpod container, in-memory caches, or globals.
///
/// We rebuild a minimal version of the outbox stack here, drain once,
/// and tear it down. Errors are mapped to `false` so workmanager
/// reschedules with backoff per platform conventions.
///
/// `vm:entry-point` keeps the Dart compiler from tree-shaking the
/// callback when AOT-compiling for release.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return runOutboxBackgroundCycle();
  });
}

/// Single drain cycle. Exposed (non-private) so tests can drive the
/// same code path the dispatcher would, with mocked dependencies.
///
/// Returns `true` when the cycle completed without throwing — including
/// the no-op case (no signed-in user, offline). Returns `false` so
/// workmanager schedules a retry.
Future<bool> runOutboxBackgroundCycle({
  BackgroundOutboxBootstrap? bootstrap,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final boot = bootstrap ?? const _DefaultBackgroundOutboxBootstrap();

  AppDatabase? db;
  ConnectivityService? connectivity;
  try {
    final tokens = boot.tokens();
    final userId = await tokens.readUserId();
    if (userId == null || userId.isEmpty) {
      // Nothing to drain — user is signed out. Returning true tells
      // workmanager not to retry; the caller will reschedule when the
      // user logs back in.
      return true;
    }

    db = await boot.openDatabase();
    final imageStore = await boot.openImageStore();
    connectivity = boot.openConnectivity();

    final apiClient = boot.buildApiClient(tokens);
    final remote = CheckinsRemoteSource(apiClient);
    final sender = CheckinOutboxSender(remote);
    final service = OutboxService(
      dao: OutboxDao(db.db),
      imageStore: imageStore,
      connectivity: connectivity,
      sender: sender,
    );

    try {
      await service.drain(userId: userId);
    } finally {
      await service.dispose();
    }
    return true;
  } catch (_) {
    return false;
  } finally {
    // NOTE: We do NOT close the database connection (db?.close()) here.
    // In sqflite, when running in the background isolate on Android/iOS,
    // it shares the same native database connection/instance with the
    // main isolate (as they run in the same OS process). Calling close()
    // in the background task would close the native database handle,
    // leading to DatabaseException(database_closed 1) in the main app.
    try {
      await connectivity?.dispose();
    } catch (_) {/* best-effort */}
  }
}

/// Pluggable factory for the background dependencies. Production code
/// uses [_DefaultBackgroundOutboxBootstrap]; tests inject a stub to
/// avoid touching real plugins inside the unit-test harness.
abstract class BackgroundOutboxBootstrap {
  SecureTokenStore tokens();
  Future<AppDatabase> openDatabase();
  Future<ImageStore> openImageStore();
  ConnectivityService openConnectivity();
  ApiClient buildApiClient(SecureTokenStore tokens);
}

class _DefaultBackgroundOutboxBootstrap implements BackgroundOutboxBootstrap {
  const _DefaultBackgroundOutboxBootstrap();

  @override
  SecureTokenStore tokens() => SecureTokenStore();

  @override
  Future<AppDatabase> openDatabase() => AppDatabase.open();

  @override
  Future<ImageStore> openImageStore() => ImageStore.createDefault();

  @override
  ConnectivityService openConnectivity() {
    // Background isolate has no preference cache for /health probes
    // yet — assume the OS already gated the task on
    // `NetworkType.connected`, so a permissive probe is fine. If we
    // ever see false positives, swap this for a real HEAD /health.
    return ConnectivityService();
  }

  @override
  ApiClient buildApiClient(SecureTokenStore tokens) {
    return ApiClient(
      tokens: tokens,
      // Background isolate can't navigate the user out — surface auth
      // failures to logs and let the next foreground session prompt.
      onAuthFailure: () {},
    );
  }
}
