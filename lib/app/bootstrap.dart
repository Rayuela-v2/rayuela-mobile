import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/locale/locale_controller.dart';
import '../core/network/api_client.dart';
import '../core/storage/image_store.dart';
import '../core/storage/secure_token_store.dart';
import '../core/sync/app_database.dart';
import '../core/sync/connectivity_service.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../shared/providers/core_providers.dart';

/// Builds the root [ProviderContainer] with the real implementations wired in.
///
/// `secureTokenStoreProvider` and `apiClientProvider` are declared as
/// `throw UnimplementedError` in `shared/providers/core_providers.dart`; we
/// override them here so feature code can stay ignorant of construction.
///
/// Phase 2 additions: opens the [AppDatabase], the [ImageStore], and the
/// [ConnectivityService] up-front so the outbox is ready the first time
/// the user composes a check-in.
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

  // Connectivity wraps a `connectivity_plus` instance and a reachability
  // probe. Sprint A wires the default "always reachable" probe; Sprint
  // B will swap it for one that hits the backend's `/health` endpoint.
  final connectivity = ConnectivityService();

  // Best-effort cleanup of orphaned image folders left over from a
  // crash mid-enqueue. Runs in the background — don't block startup.
  // ignore: unawaited_futures
  imageStore.sweepOrphans(knownIds: const {});

  // We need a forward reference to the container so the API client can call
  // back into Riverpod when a refresh ultimately fails.
  late final ProviderContainer container;

  final apiClient = ApiClient(
    tokens: tokens,
    onAuthFailure: () {
      // Fired by RefreshInterceptor after a 401 + refresh-token failure.
      container.read(authControllerProvider.notifier).forceSignOut();
    },
  );

  container = ProviderContainer(
    overrides: [
      secureTokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(apiClient),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(appDb),
      imageStoreProvider.overrideWithValue(imageStore),
      connectivityServiceProvider.overrideWithValue(connectivity),
    ],
  );

  // Touch the auth providers so the controller is constructed eagerly
  // (it'll sit in AuthStateInitial until the splash runs bootstrap()).
  // ignore: unused_local_variable
  final _ = container.read(authRepositoryProvider);

  return container;
}
