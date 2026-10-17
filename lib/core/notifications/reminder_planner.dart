import '../../features/bills/data/bill.dart';
import '../format/money.dart';

/// A local notification to schedule, at a wall-clock [when] on the device.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.dueDate,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;

  /// The bills' due date — the notification opens "Contas a pagar" there.
  final DateTime dueDate;
}

/// Hour of the day (local time) every reminder fires.
const reminderHour = 9;

/// iOS keeps at most 64 pending local notifications per app; stay under it.
const maxPendingReminders = 60;

/// Turns unpaid bills into reminders: one the day before and one on the due
/// date, both at [reminderHour], grouping every bill due the same day into a
/// single notification. Reminders whose time already passed are skipped.
List<PlannedReminder> planReminders(List<Bill> bills, DateTime now) {
  final byDate = <DateTime, List<Bill>>{};
  for (final bill in bills.where((b) => !b.paid)) {
    final day = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );
    byDate.putIfAbsent(day, () => []).add(bill);
  }

  final reminders = <PlannedReminder>[];
  for (final entry in byDate.entries) {
    final dueDate = entry.key;
    final dueBills = entry.value;
    final names = dueBills.map((b) => b.description).join(', ');
    final total = dueBills.fold<double>(
      0,
      (sum, b) => sum + (double.tryParse(b.amount) ?? 0),
    );
    final body = '$names · ${formatCurrency(total.toStringAsFixed(2))}';
    final plural = dueBills.length > 1;

    final dayBefore = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - 1,
      reminderHour,
    );
    final onDay = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      reminderHour,
    );

    if (dayBefore.isAfter(now)) {
      reminders.add(
        PlannedReminder(
          id: _id(dueDate, 0),
          when: dayBefore,
          title: plural
              ? 'Amanhã vencem ${dueBills.length} contas'
              : 'Amanhã vence',
          body: body,
          dueDate: dueDate,
        ),
      );
    }
    if (onDay.isAfter(now)) {
      reminders.add(
        PlannedReminder(
          id: _id(dueDate, 1),
          when: onDay,
          title: plural
              ? 'Hoje vencem ${dueBills.length} contas'
              : 'Hoje vence',
          body: body,
          dueDate: dueDate,
        ),
      );
    }
  }

  reminders.sort((a, b) => a.when.compareTo(b.when));
  return reminders.take(maxPendingReminders).toList();
}

/// Stable per (date, slot), so rescheduling replaces rather than duplicates.
int _id(DateTime date, int slot) =>
    (date.year * 10000 + date.month * 100 + date.day) * 10 + slot;
