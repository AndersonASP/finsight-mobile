import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../storage/token_storage.dart';
import '../../features/auth/application/auth_controller.dart';
import 'api_client.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return buildApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: () => ref.read(authControllerProvider.notifier).signOut(),
  );
});
