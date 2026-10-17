import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists JWT access/refresh tokens in the iOS Keychain (via flutter_secure_storage).
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'finsight.access_token';
  static const _refreshTokenKey = 'finsight.refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveAccessToken(String accessToken) {
    return _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
