import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/core_providers.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/sources/auth_remote_source.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteSourceProvider = Provider<AuthRemoteSource>((ref) {
  return AuthRemoteSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteSourceProvider),
    tokens: ref.watch(secureTokenStoreProvider),
  );
});
