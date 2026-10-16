import 'package:flutter_riverpod/legacy.dart';

/// First-of-month cursor shared by the Saldos/Totais/Tags screens, mirroring
/// the reference app's "< out/26 >" month navigator.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

extension SelectedMonthX on DateTime {
  DateTime get nextMonth => DateTime(year, month + 1);
  DateTime get previousMonth => DateTime(year, month - 1);
}
