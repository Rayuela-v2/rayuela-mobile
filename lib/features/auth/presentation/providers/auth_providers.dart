import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/sources/auth_remote_source.dart';
import '../../data/sources/google_auth_service.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteSourceProvider = Provider<AuthRemoteSource>((ref) {
  return AuthRemoteSource(ref.watch(apiClientProvider));
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService(
    // iOS-only; harmless to leave null on Android.
    iosClientId: Env.googleClientIdIos.isEmpty ? null : Env.googleClientIdIos,
    // Web client ID drives `serverClientId` on both platforms so the
    // backend can verify the `aud` of the returned idToken.
    webClientId: Env.googleClientIdWeb.isEmpty ? null : Env.googleClientIdWeb,
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteSourceProvider),
    tokens: ref.watch(secureTokenStoreProvider),
  );
});
