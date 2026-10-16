import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_shell.dart';

/// Resolves the session state for routing purposes. A failure reading the
/// stored session (e.g. keychain unavailable) is treated as unauthenticated
/// rather than leaving the app stuck on a splash screen forever; `null` means
/// the check is still in flight.
AuthStatus? _resolveAuthStatus(AsyncValue<AuthStatus> state) {
  if (state.hasValue) return state.value;
  if (state.hasError) return AuthStatus.unauthenticated;
  return null;
}

/// Bridges Riverpod's [authControllerProvider] to go_router's `refreshListenable`
/// so `redirect` is re-evaluated on every auth change *without* recreating the
/// [GoRouter] (and therefore its Navigator) itself. Recreating the router on
/// every Loading/Error/Data transition would tear down and rebuild the current
/// page's State mid-flight — e.g. dropping an in-progress login error message.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AsyncValue<AuthStatus>>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AuthStatus>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authStatus = _resolveAuthStatus(ref.read(authControllerProvider));
      final isLoggingIn = state.matchedLocation == '/login';

      if (authStatus == null) {
        // Still resolving the stored session; stay put until it settles.
        return null;
      }
      if (authStatus == AuthStatus.unauthenticated && !isLoggingIn) {
        return '/login';
      }
      if (authStatus == AuthStatus.authenticated && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _RootGate()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ],
  );
});

/// Renders the home shell once authenticated, or a splash spinner while the
/// stored session is still being resolved / redirected.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = _resolveAuthStatus(ref.watch(authControllerProvider));
    if (authStatus != AuthStatus.authenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const HomeShell();
  }
}
