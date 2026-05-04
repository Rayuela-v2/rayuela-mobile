import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';

import '../core/locale/locale_controller.dart';
import '../core/network/api_client.dart';
import '../core/network/api_paths.dart';
import '../core/storage/image_store.dart';
import '../core/storage/secure_token_store.dart';
import '../core/sync/app_database.dart';
import '../core/sync/connectivity_service.dart';
import '../core/sync/outbox/outbox_dao.dart';
import '../core/sync/outbox/outbox_lifecycle.dart';
import '../core/sync/outbox/outbox_service.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/checkin/data/sources/checkin_outbox_sender.dart';
import '../features/checkin/data/sources/checkins_remote_source.dart';
import '../shared/providers/core_providers.dart';

/// Builds the root [ProviderContainer] with the real implementations wired in.
///
/// `secureTokenStoreProvider` and `apiClientProvider` are declared as
/// `throw UnimplementedError` in `shared/providers/core_providers.dart`; we
/// override them here so feature code can stay ignorant of construction.
///
/// Phase 2 additions: opens the [AppDatabase], [ImageStore], and
/// [ConnectivityService] up-front, then composes the [OutboxService]
/// (with the check-in sender) and the [OutboxLifecycle] listener.
Future<ProviderContainer> bootstrapContainer() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = SecureTokenStore();
  final prefs = await SharedPreferences.getInstance();

  // Open offline foundations in parallel — none of them depend on each
  // other and they all touch I/O.
  final results = await Future.wait<Object>([
    AppDatabase.open(),
    ImageStore.createDefault(),
  ]);
  final appDb = results[0] as AppDatabase;
  final imageStore = results[1] as ImageStore;

  // We need a forward reference to the API client for the connectivity
  // probe — declared `late` so the closure captures the eventual value.
  late final ApiClient apiClient;

  // Connectivity wraps a `connectivity_plus` instance and a reachability
  // probe. The probe hits `GET /health` (no auth, no logging) with a
  // tight timeout: any HTTP response — success or error — means we
  // reached the backend, only DioExceptions of type connectionError /
  // timeout count as "unreachable".
  final connectivity = ConnectivityService(
    probe: () async {
      try {
        await apiClient.raw.get<dynamic>(
          ApiPaths.health,
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
            // Some backends 405 on GET /health; we still consider that
            // "reachable", which is why we don't validate the status.
            validateStatus: (_) => true,
          ),
        );
        return true;
      } on DioException catch (e) {
        return e.type != DioExceptionType.connectionTimeout &&
            e.type != DioExceptionType.receiveTimeout &&
            e.type != DioExceptionType.sendTimeout &&
            e.type != DioExceptionType.connectionError;
      } catch (_) {
        return false;
      }
    },
  );

  // We need a forward reference to the container so the API client can call
  // back into Riverpod when a refresh ultimately fails.
  late final ProviderContainer container;

  apiClient = ApiClient(
    tokens: tokens,
    onAuthFailure: () {
      // Fired by RefreshInterceptor after a 401 + refresh-token failure.
      container.read(authControllerProvider.notifier).forceSignOut();
    },
  );

  // Compose the outbox stack. The DAO is just a wrapper around the DB,
  // the sender knows how to call POST /checkin with an Idempotency-Key,
  // and the service ties them together with the connectivity probe and
  // the image store.
  final outboxDao = OutboxDao(appDb.db);
  final remoteCheckins = CheckinsRemoteSource(apiClient);
  final outboxSender = CheckinOutboxSender(remoteCheckins);
  final outboxService = OutboxService(
    dao: outboxDao,
    imageStore: imageStore,
    connectivity: connectivity,
    sender: outboxSender,
  );
  final outboxLifecycle = OutboxLifecycle(
    outbox: outboxService,
    connectivity: connectivity,
  );

  // Best-effort cleanup of orphaned image folders left over from a
  // crash mid-enqueue. Runs in the background — don't block startup.
  // Now that the DAO is up we can pass `knownIds` so we never delete
  // a folder still referenced by a queued row.
  // ignore: unawaited_futures
  outboxDao.knownIds().then(
        (ids) => imageStore.sweepOrphans(knownIds: ids),
      );

  container = ProviderContainer(
    overrides: [
      secureTokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(apiClient),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(appDb),
      imageStoreProvider.overrideWithValue(imageStore),
      connectivityServiceProvider.overrideWithValue(connectivity),
      outboxDaoProvider.overrideWithValue(outboxDao),
      outboxServiceProvider.overrideWithValue(outboxService),
      outboxLifecycleProvider.overrideWithValue(outboxLifecycle),
    ],
  );

  // Touch the auth providers so the controller is constructed eagerly
  // (it'll sit in AuthStateInitial until the splash runs bootstrap()).
  // ignore: unused_local_variable
  final _ = container.read(authRepositoryProvider);

  // Bind / unbind the outbox lifecycle as the auth state changes. We
  // listen on the container directly because Riverpod's `.listen` API
  // is the cleanest way to react to state transitions outside the
  // widget tree. The subscription lives as long as the container.
  container.listen<AuthState>(
    authControllerProvider,
    (previous, next) {
      if (next is AuthStateAuthenticated) {
        outboxLifecycle.bind(next.user.id);
      } else {
        outboxLifecycle.unbind();
      }
    },
    fireImmediately: true,
  );

  return container;
}
