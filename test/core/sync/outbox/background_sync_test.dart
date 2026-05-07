import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/network/api_client.dart';
import 'package:rayuela_mobile/core/storage/image_store.dart';
import 'package:rayuela_mobile/core/storage/secure_token_store.dart';
import 'package:rayuela_mobile/core/sync/app_database.dart';
import 'package:rayuela_mobile/core/sync/connectivity_service.dart';
import 'package:rayuela_mobile/core/sync/outbox/background_sync.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Bootstrap that throws if anything beyond `tokens()` is touched —
/// keeps the "no userId → no-op" test honest by failing loud if the
/// dispatcher accidentally proceeds past the early return.
class _NoUserBootstrap implements BackgroundOutboxBootstrap {
  _NoUserBootstrap(this._tokens);
  final SecureTokenStore _tokens;

  @override
  SecureTokenStore tokens() => _tokens;

  @override
  Future<AppDatabase> openDatabase() async {
    fail('openDatabase must NOT run when there is no signed-in user');
  }

  @override
  Future<ImageStore> openImageStore() async {
    fail('openImageStore must NOT run when there is no signed-in user');
  }

  @override
  ConnectivityService openConnectivity() {
    fail('openConnectivity must NOT run when there is no signed-in user');
  }

  @override
  ApiClient buildApiClient(SecureTokenStore tokens) {
    fail('buildApiClient must NOT run when there is no signed-in user');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('runOutboxBackgroundCycle', () {
    test('returns true and skips the rest when no user is signed in',
        () async {
      final storage = _MockSecureStorage();
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      final tokens = SecureTokenStore(storage);
      final ok = await runOutboxBackgroundCycle(
        bootstrap: _NoUserBootstrap(tokens),
      );

      expect(ok, isTrue,
          reason: 'no-op cycle is not a failure — workmanager should not retry');
    });
  });
}
