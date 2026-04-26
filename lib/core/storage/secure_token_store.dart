import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists auth tokens in the platform keystore/keychain.
///
/// Never log or print the values this class returns.
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String _accessTokenKey = 'rayuela.access_token';
  static const String _refreshTokenKey = 'rayuela.refresh_token';
  static const String _userIdKey = 'rayuela.user_id';

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);
  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (userId != null) {
      await _storage.write(key: _userIdKey, value: userId);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
  }
}
