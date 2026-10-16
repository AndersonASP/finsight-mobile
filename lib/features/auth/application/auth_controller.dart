import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../data/auth_repository.dart';

enum AuthStatus { authenticated, unauthenticated }

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthStatus>(AuthController.new);

class AuthController extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() async {
    final token = await ref.watch(tokenStorageProvider).readAccessToken();
    return token != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  /// Throws the underlying error (e.g. [DioException]) on failure, in addition
  /// to recording it in [state], so the caller can show a specific message.
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).login(email, password);
      state = const AsyncData(AuthStatus.authenticated);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(AuthStatus.unauthenticated);
  }
}
