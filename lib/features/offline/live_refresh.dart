import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import '../../core/home_widget/widget_sync.dart';
import '../../core/network/network_providers.dart';
import '../../core/offline/connectivity.dart';
import '../accounts/application/accounts_providers.dart';
import '../bills/application/bills_providers.dart';
import '../budget/application/budget_providers.dart';
import '../cards/application/cards_providers.dart';
import '../categories/application/categories_providers.dart';
import '../debts/application/debts_providers.dart';
import '../insights/data/savings_capacity.dart';
import '../invoices/application/invoices_providers.dart';
import '../ledger/application/day_detail_providers.dart';
import '../ledger/application/ledger_providers.dart';
import '../quick_entry/application/quick_entry_providers.dart';
import '../totals/application/totals_providers.dart';
import '../wealth/application/wealth_providers.dart';

final liveRefreshProvider = Provider<LiveRefresh>((ref) {
  final service = LiveRefresh(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Makes changes made anywhere else — the Claude MCP, an Apple Pay
/// automation, another device — show up without reopening the app.
///
/// While the app is in the foreground it polls `GET /sync/version` (a
/// counter the API bumps after every write) and, only when it moved,
/// refetches every screen's data, the widget snapshot and the reminders.
class LiveRefresh {
  LiveRefresh(this._ref);

  final Ref _ref;
  int? _knownVersion;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _checking = false;

  static const _interval = Duration(seconds: 15);

  void start() {
    if (_lifecycle != null) return;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _startTimer();
        unawaited(check());
      },
      onPause: _stopTimer,
    );
    _startTimer();
    unawaited(check());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => check());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _stopTimer();
    _lifecycle?.dispose();
  }

  /// Refetches everything if the server's data changed since last time.
  Future<void> check() async {
    if (_checking || _ref.read(connectivityProvider)) return;
    _checking = true;
    try {
      final response = await _ref.read(dioProvider).get('/sync/version');
      final version = (response.data as Map)['version'] as int;
      final changed = _knownVersion != null && version != _knownVersion;
      _knownVersion = version;
      if (changed) await refreshAll();
    } catch (_) {
      // Offline or server hiccup: the next tick tries again.
    } finally {
      _checking = false;
    }
  }

  /// Every screen's server data, refetched in place (the old values stay on
  /// screen until the new ones arrive — no spinners, no lost scroll).
  Future<void> refreshAll() async {
    for (final provider in <ProviderOrFamily>[
      dailyBalanceProvider,
      dayDetailProvider,
      monthlyTotalsProvider,
      savingsCapacityProvider,
      billsProvider,
      wealthSummaryProvider,
      wealthHistoryProvider,
      accountsListProvider,
      cardsListProvider,
      cardInvoicesProvider,
      categoriesListProvider,
      budgetItemsListProvider,
      budgetSummaryProvider,
      debtsListProvider,
      walletMappingsProvider,
    ]) {
      _ref.invalidate(provider);
    }
    await _ref.read(widgetSyncProvider).refresh(force: true);
    await _ref.read(billsControllerProvider).rescheduleReminders();
  }
}
