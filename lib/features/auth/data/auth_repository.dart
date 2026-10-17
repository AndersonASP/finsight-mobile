import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/token_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final accessToken = response.data['accessToken'] as String;
    final refreshToken = response.data['refreshToken'] as String;
    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// Revokes the session server-side (best effort — offline or a failing
  /// server must not block logging out), then forgets the local tokens.
  Future<void> signOut() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      } catch (_) {}
    }
    await _tokenStorage.clear();
  }
}
