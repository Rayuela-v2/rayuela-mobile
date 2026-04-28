import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/locale/locale_controller.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_token_store.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../shared/providers/core_providers.dart';

/// Builds the root [ProviderContainer] with the real implementations wired in.
///
/// `secureTokenStoreProvider` and `apiClientProvider` are declared as
/// `throw UnimplementedError` in `shared/providers/core_providers.dart`; we
/// override them here so feature code can stay ignorant of construction.
Future<ProviderContainer> bootstrapContainer() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = SecureTokenStore();
  final prefs = await SharedPreferences.getInstance();

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
    ],
  );

  // Touch the auth providers so the controller is constructed eagerly
  // (it'll sit in AuthStateInitial until the splash runs bootstrap()).
  // ignore: unused_local_variable
  final _ = container.read(authRepositoryProvider);

  return container;
}
