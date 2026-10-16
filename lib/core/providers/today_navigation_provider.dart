import 'package:flutter_riverpod/legacy.dart';

/// Bumped whenever the user taps the "go to today" calendar button, wherever
/// it appears in the app. `HomeShell` listens to switch to the Saldos tab;
/// `SaldosScreen` listens to reset the visible month and scroll to today's row.
final goToTodaySignalProvider = StateProvider<int>((ref) => 0);
