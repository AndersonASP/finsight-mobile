import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/offline/offline_store.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keeps the native splash (see flutter_native_splash config in
  // pubspec.yaml) on screen past Flutter's first frame — `_RootGate` removes
  // it once the stored session check actually resolves, so there's no gap
  // where a blank/white frame or a bare spinner flashes before it.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await initializeDateFormatting('pt_BR');
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [offlineStoreProvider.overrideWithValue(OfflineStore(prefs))],
      child: const FinSightApp(),
    ),
  );
}

class FinSightApp extends ConsumerWidget {
  const FinSightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FinSight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
