import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/secure_token_store.dart';

/// Root providers shared across features. Overridden in `main.dart` so the
/// app can wire real implementations without touching feature code.
final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Override in bootstrap');
});
