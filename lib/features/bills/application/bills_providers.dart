import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/home_widget/widget_sync.dart';
import '../../../core/notifications/reminder_notifications.dart';
import '../../../core/notifications/reminder_planner.dart';
import '../../../core/offline/connectivity.dart';
import '../../../core/offline/offline_store.dart';
import '../data/bill.dart';
import '../data/bills_repository.dart';

/// The single window every bills read uses (screen, badge and reminders),
/// so they all share one cached response: overdue bills from the last two
/// months, plus everything due in the next ~45 days.
({DateTime from, DateTime to}) billsWindow(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return (
    from: DateTime(today.year, today.month - 2, today.day),
    to: DateTime(today.year, today.month, today.day + 45),
  );
}

// ------------------------------------------------------------ paid toggles

/// Paid checks made on this device that the server hasn't confirmed yet
/// (offline, or still in flight): bill id → (kind, paid).
final pendingPaidProvider =
    NotifierProvider<PendingPaidNotifier, Map<String, (BillKind, bool)>>(
      PendingPaidNotifier.new,
    );

class PendingPaidNotifier extends Notifier<Map<String, (BillKind, bool)>> {
  static const _storeKey = 'bills.pendingPaid';

  OfflineStore get _store => ref.read(offlineStoreProvider);

  @override
  Map<String, (BillKind, bool)> build() {
    final raw = _store.read(_storeKey);
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        e.key as String: (
          BillKind.fromApi((e.value as Map)['kind'] as String),
          (e.value as Map)['paid'] as bool,
        ),
    };
  }

  void set(BillKind kind, String id, bool paid) =>
      _save({...state, id: (kind, paid)});

  void remove(String id) => _save({...state}..remove(id));

  void _save(Map<String, (BillKind, bool)> next) {
    state = next;
    _store.write(_storeKey, {
      for (final e in next.entries)
        e.key: {'kind': e.value.$1.apiValue, 'paid': e.value.$2},
    });
  }
}

List<Bill> _applyPending(
  List<Bill> bills,
  Map<String, (BillKind, bool)> pending,
) => [
  for (final b in bills)
    pending.containsKey(b.id) ? b.copyWith(paid: pending[b.id]!.$2) : b,
];

/// Every bill in [billsWindow] — live, or cached when offline — with paid
/// checks not yet synced applied on top.
final billsProvider = FutureProvider.autoDispose<List<Bill>>((ref) async {
  ref.watch(connectivityProvider);
  final pending = ref.watch(pendingPaidProvider);
  final repository = ref.watch(billsRepositoryProvider);
  final window = billsWindow(DateTime.now());
  final bills = await networkOrCache(
    ref,
    network: () => repository.list(from: window.from, to: window.to),
    cache: repository.cachedList,
  );
  return _applyPending(bills, pending);
});

/// Unpaid bills whose due date already passed — the Menu badge.
final overdueBillsCountProvider = Provider.autoDispose<int>((ref) {
  final bills = ref.watch(billsProvider).value ?? const [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return bills.where((b) => !b.paid && b.dueDate.isBefore(today)).length;
});

// ------------------------------------------------------------ reminders

/// `null` = never asked (show the "ativar lembretes" prompt), else the choice.
final remindersEnabledProvider =
    NotifierProvider<RemindersEnabledNotifier, bool?>(
      RemindersEnabledNotifier.new,
    );

class RemindersEnabledNotifier extends Notifier<bool?> {
  static const _storeKey = 'settings.remindersEnabled';

  @override
  bool? build() => ref.read(offlineStoreProvider).read(_storeKey) as bool?;

  void set(bool enabled) {
    state = enabled;
    ref.read(offlineStoreProvider).write(_storeKey, enabled);
  }
}

final billsControllerProvider = Provider<BillsController>(BillsController.new);

class BillsController {
  BillsController(this._ref);

  final Ref _ref;

  BillsRepository get _repository => _ref.read(billsRepositoryProvider);
  PendingPaidNotifier get _pending => _ref.read(pendingPaidProvider.notifier);

  /// Flips the paid check: shown immediately, sent when possible, and the
  /// reminders are rescheduled right away (paying early cancels them).
  Future<void> setPaid(Bill bill, bool paid) async {
    _pending.set(bill.kind, bill.id, paid);
    await syncPending();
    await rescheduleReminders();
    await _ref.read(widgetSyncProvider).refresh(force: true);
  }

  /// Sends queued paid checks. Stops at the first connection failure (kept
  /// for later); a check the server refuses (e.g. the bill was deleted) is dropped.
  Future<void> syncPending() async {
    final connectivity = _ref.read(connectivityProvider.notifier);
    for (final entry in _ref.read(pendingPaidProvider).entries) {
      final (kind, paid) = entry.value;
      try {
        await _repository.setPaid(kind, entry.key, paid);
        connectivity.markOnline();
      } catch (error) {
        if (isOfflineError(error)) {
          connectivity.markOffline();
          return;
        }
        final status = error is DioException
            ? error.response?.statusCode
            : null;
        if (status == null || status >= 500) return;
      }
      // Refresh the cached copy before dropping the override, so an
      // offline read right after doesn't flash the old state.
      try {
        final window = billsWindow(DateTime.now());
        await _repository.list(from: window.from, to: window.to);
      } catch (_) {}
      _pending.remove(entry.key);
    }
  }

  /// Turns on reminders (asking the OS for permission). False when denied.
  Future<bool> enableReminders() async {
    final granted = await _ref
        .read(reminderNotificationsProvider)
        .requestPermission();
    _ref.read(remindersEnabledProvider.notifier).set(granted);
    await rescheduleReminders();
    return granted;
  }

  Future<void> disableReminders() async {
    _ref.read(remindersEnabledProvider.notifier).set(false);
    await _ref.read(reminderNotificationsProvider).cancelAll();
  }

  /// Re-plans every reminder from the latest bills (cached when offline).
  /// Called on startup/resume, after sync and whenever a check changes.
  Future<void> rescheduleReminders() async {
    final notifications = _ref.read(reminderNotificationsProvider);
    if (_ref.read(remindersEnabledProvider) != true) return;
    List<Bill>? bills;
    try {
      final window = billsWindow(DateTime.now());
      bills = await _repository.list(from: window.from, to: window.to);
    } catch (_) {
      bills = _repository.cachedList();
    }
    if (bills == null) return;
    final withPending = _applyPending(bills, _ref.read(pendingPaidProvider));
    await notifications.replaceAll(planReminders(withPending, DateTime.now()));
  }
}
