import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/home_widget/widget_sync.dart';
import '../../core/network/network_providers.dart';
import '../../core/offline/connectivity.dart';
import '../accounts/data/accounts_repository.dart';
import '../bills/application/bills_providers.dart';
import '../categories/data/categories_repository.dart';
import '../reports/data/reports_repository.dart';
import '../transactions/data/fin_transaction.dart';
import '../transactions/data/transactions_repository.dart';
import 'pending_changes.dart';

/// Messages about queued changes the server refused when they were synced —
/// the Saldos screen shows each one as a snackbar and then clears the list.
final syncRejectionsProvider = StateProvider<List<String>>((ref) => const []);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.listen(connectivityProvider, (_, _) => service._updateTimer());
  ref.listen(pendingChangesProvider, (_, _) => service._updateTimer());
  ref.onDispose(service.dispose);
  return service;
});

/// Keeps the offline copy of the Saldos tab in sync with the server: writes
/// lançamentos online when possible (queueing them otherwise), pushes the
/// queue once the API is reachable again, and refreshes the cached months.
class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _started = false;
  bool _flushing = false;
  DateTime? _lastFullRefresh;
  final Map<String, DateTime> _monthPrefetchedAt = {};

  static const _retryInterval = Duration(seconds: 20);
  static const _refreshThrottle = Duration(minutes: 5);

  /// How far (in months) from the current one a cached month is kept.
  static const _maxCachedMonthDistance = 12;

  TransactionsRepository get _transactions =>
      _ref.read(transactionsRepositoryProvider);
  ReportsRepository get _reports => _ref.read(reportsRepositoryProvider);
  PendingChangesNotifier get _pending =>
      _ref.read(pendingChangesProvider.notifier);
  ConnectivityNotifier get _connectivity =>
      _ref.read(connectivityProvider.notifier);

  /// Called once the user is in the app: syncs anything queued from a
  /// previous session and refreshes the cache, now and on every resume.
  void start() {
    if (_started) return;
    _started = true;
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _onResume();
  }

  void _onResume() {
    unawaited(_syncAndRefresh());
  }

  Future<void> _syncAndRefresh() async {
    await flush();
    if (!_connectivity.isOffline) await refreshCache();
    // Paid checks made offline, and reminders re-planned from fresh bills
    // (a new recurring saída, or one paid on another device).
    final bills = _ref.read(billsControllerProvider);
    await bills.syncPending();
    await bills.rescheduleReminders();
    await _ref.read(widgetSyncProvider).refresh(force: true);
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
  }

  /// Retries on a timer only while there's something to wait for: queued
  /// changes, or a lost connection whose return we want to notice.
  void _updateTimer() {
    final needed =
        _started &&
        (_connectivity.isOffline ||
            _ref.read(pendingChangesProvider).isNotEmpty);
    if (!needed) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_retryInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_ref.read(pendingChangesProvider).isNotEmpty) {
      await _syncAndRefresh();
      return;
    }
    try {
      await _ref.read(dioProvider).get('/health');
      _connectivity.markOnline();
      await refreshCache(force: true);
    } catch (error) {
      if (isOfflineError(error)) _connectivity.markOffline();
    }
  }

  // ---------------------------------------------------------------- writes

  /// Creates [draft] (whose id is ignored) on the server, or queues it.
  /// Returns true when it was only saved on this device.
  Future<bool> createTransaction(FinTransaction draft) {
    return _onlineOrQueue(
      changedDate: draft.date,
      online: () => _transactions.create(
        accountId: draft.accountId,
        type: draft.type,
        amount: draft.amount,
        date: draft.date,
        categoryId: draft.categoryId,
        description: draft.description,
        counterpartAccountId: draft.counterpartAccountId,
      ),
      queue: () => _pending.create(_copyWithId(draft, newLocalTransactionId())),
    );
  }

  /// Saves [updated] over [original] (both carrying the same id).
  Future<bool> updateTransaction({
    required FinTransaction original,
    required FinTransaction updated,
  }) async {
    if (isLocalTransactionId(updated.id)) {
      _pending.edit(serverVersion: original, updated: updated);
      return _afterQueued();
    }
    return _onlineOrQueue(
      changedDate: original.date.isBefore(updated.date)
          ? original.date
          : updated.date,
      online: () => _sendUpdate(updated),
      queue: () => _pending.edit(serverVersion: original, updated: updated),
    );
  }

  /// Deletes lançamento [id] (only the single occurrence). Throws
  /// [OfflineException] when offline and the lançamento isn't known locally.
  Future<bool> deleteTransaction(String id) async {
    final pendingVersion = _ref
        .read(pendingChangesProvider)
        .currentVersionOf(id);
    if (isLocalTransactionId(id)) {
      if (pendingVersion != null) _pending.delete(pendingVersion);
      return _afterQueued();
    }
    final known = pendingVersion ?? _transactions.cachedTransaction(id);
    return _onlineOrQueue(
      changedDate: known?.date,
      online: () => _transactions.delete(id),
      queue: () {
        if (known == null) {
          throw const OfflineException(
            'Sem conexão: este lançamento ainda não foi salvo no aparelho. '
            'Abra este mês com internet uma vez para poder excluí-lo offline.',
          );
        }
        _pending.delete(known);
      },
    );
  }

  /// The current version of lançamento [id] — its queued offline edit if
  /// any, else the server's (falling back to the cached copy offline).
  Future<FinTransaction> loadTransaction(String id) async {
    final pendingVersion = _ref
        .read(pendingChangesProvider)
        .currentVersionOf(id);
    if (pendingVersion != null) return pendingVersion;
    if (isLocalTransactionId(id)) {
      throw const OfflineException('Lançamento não encontrado.');
    }
    return networkOrCache(
      _ref,
      network: () => _transactions.get(id),
      cache: () => _transactions.cachedTransaction(id),
    );
  }

  /// Runs an action that only the server can do (a recurring series, a
  /// "esta e as futuras" delete, a card purchase), turning "no connection"
  /// into a readable [OfflineException].
  Future<T> requireOnline<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      _connectivity.markOnline();
      return result;
    } catch (error) {
      if (!isOfflineError(error)) rethrow;
      _connectivity.markOffline();
      throw const OfflineException(
        'Sem conexão: essa ação precisa de internet.',
      );
    }
  }

  Future<bool> _onlineOrQueue({
    required DateTime? changedDate,
    required Future<Object?> Function() online,
    required void Function() queue,
  }) async {
    // With something already queued, go through the queue too, so changes
    // reach the server in the order they were made.
    final canGoDirect =
        !_connectivity.isOffline && _ref.read(pendingChangesProvider).isEmpty;
    if (canGoDirect) {
      try {
        await online();
        _connectivity.markOnline();
        if (changedDate != null) {
          unawaited(refreshCache(changedDate: changedDate));
        }
        unawaited(_ref.read(widgetSyncProvider).refresh(force: true));
        return false;
      } catch (error) {
        if (!isOfflineError(error)) rethrow;
        _connectivity.markOffline();
      }
    }
    queue();
    return _afterQueued();
  }

  Future<bool> _afterQueued() async {
    if (_connectivity.isOffline) {
      unawaited(flush());
      return true;
    }
    await flush();
    return _connectivity.isOffline;
  }

  Future<FinTransaction> _sendUpdate(FinTransaction t) => _transactions.update(
    t.id,
    accountId: t.accountId,
    type: t.type,
    amount: t.amount,
    date: t.date,
    categoryId: t.categoryId,
    description: t.description ?? '',
    counterpartAccountId: t.counterpartAccountId,
  );

  // ---------------------------------------------------------------- flush

  /// Pushes every queued change to the server, oldest kinds first. Stops at
  /// the first connection failure (retried later); a change the server
  /// refuses (4xx) is dropped and reported via [syncRejectionsProvider].
  Future<void> flush() async {
    if (_flushing) return;
    if (_ref.read(pendingChangesProvider).isEmpty) return;
    _flushing = true;
    final changedDates = <DateTime>[];
    try {
      final pending = _ref.read(pendingChangesProvider);
      for (final entry in pending.creates.entries) {
        final sent = entry.value;
        if (!await _attempt(sent, () async {
          final created = await _transactions.create(
            accountId: sent.accountId,
            type: sent.type,
            amount: sent.amount,
            date: sent.date,
            categoryId: sent.categoryId,
            description: sent.description,
            counterpartAccountId: sent.counterpartAccountId,
          );
          _pending.markCreateSynced(entry.key, sent, created);
        }, discardId: entry.key)) {
          return;
        }
        changedDates.add(sent.date);
      }
      for (final entry in pending.updates.entries) {
        final sent = entry.value.after;
        if (!await _attempt(sent, () async {
          await _sendUpdate(sent);
          _pending.markUpdateSynced(entry.key, sent);
        }, discardId: entry.key)) {
          return;
        }
        changedDates.addAll([entry.value.before.date, sent.date]);
      }
      for (final entry in pending.deletes.entries) {
        final before = entry.value;
        if (!await _attempt(before, () async {
          try {
            await _transactions.delete(entry.key);
          } on DioException catch (e) {
            if (e.response?.statusCode != 404) rethrow; // already gone
          }
          _pending.markDeleteSynced(entry.key);
        }, discardId: entry.key)) {
          return;
        }
        changedDates.add(before.date);
      }
      _connectivity.markOnline();
    } finally {
      _flushing = false;
      if (changedDates.isNotEmpty) {
        changedDates.sort();
        unawaited(refreshCache(changedDate: changedDates.first));
      }
    }
  }

  /// Runs one queued change; false means "stop flushing for now".
  Future<bool> _attempt(
    FinTransaction t,
    Future<void> Function() send, {
    required String discardId,
  }) async {
    try {
      await send();
      return true;
    } catch (error) {
      if (isOfflineError(error)) {
        _connectivity.markOffline();
        return false;
      }
      final status = error is DioException ? error.response?.statusCode : null;
      if (status != null && status >= 400 && status < 500) {
        _pending.discard(discardId);
        final label = (t.description?.trim().isNotEmpty ?? false)
            ? t.description!.trim()
            : t.type.name;
        _ref.read(syncRejectionsProvider.notifier).state = [
          ..._ref.read(syncRejectionsProvider),
          'O servidor recusou "$label" (${t.date.day}/${t.date.month}) — descartado.',
        ];
        return true;
      }
      return false; // server error: keep it queued and retry later
    }
  }

  // ---------------------------------------------------------------- cache

  /// Called after the Saldos table for [month] was fetched live: also caches
  /// that month's line items (and the neighbouring months) for offline use.
  void onMonthFetched(DateTime month) {
    unawaited(_prefetchAround(month));
  }

  Future<void> _prefetchAround(DateTime month) async {
    await _prefetchAccountsAndTags();
    await _prefetchMonth(month, includeBalance: false);
    await _prefetchMonth(DateTime(month.year, month.month - 1));
    await _prefetchMonth(DateTime(month.year, month.month + 1));
  }

  /// The lançamento form needs both to work offline (and the saldo overlay
  /// needs each account's type).
  Future<void> _prefetchAccountsAndTags({bool force = false}) async {
    const key = 'accounts+categories';
    final last = _monthPrefetchedAt[key];
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _refreshThrottle) {
      return;
    }
    _monthPrefetchedAt[key] = DateTime.now();
    try {
      await _ref.read(accountsRepositoryProvider).list();
      await _ref.read(categoriesRepositoryProvider).list();
    } catch (error) {
      _monthPrefetchedAt.remove(key);
      if (isOfflineError(error)) _connectivity.markOffline();
    }
  }

  Future<void> _prefetchMonth(
    DateTime month, {
    bool includeBalance = true,
    bool force = false,
  }) async {
    final key = '${month.year}-${month.month}';
    final last = _monthPrefetchedAt[key];
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _refreshThrottle) {
      return;
    }
    _monthPrefetchedAt[key] = DateTime.now();
    final first = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    try {
      if (includeBalance) {
        await _reports.dailyBalance(year: month.year, month: month.month);
      }
      await _reports.prefetchDayDetailRange(first, lastDay);
      await _transactions.list(from: first, to: lastDay);
    } catch (error) {
      _monthPrefetchedAt.remove(key);
      if (isOfflineError(error)) _connectivity.markOffline();
    }
  }

  /// Re-fetches the cached months so they don't go stale. With
  /// [changedDate] (a lançamento on that day just changed on the server),
  /// only what it affects is refreshed: that month in full, and the saldo of
  /// every later cached month. Without it (startup/resume), everything,
  /// at most once every few minutes unless [force]d.
  Future<void> refreshCache({DateTime? changedDate, bool force = false}) async {
    try {
      final now = DateTime.now();
      final current = DateTime(now.year, now.month);
      _evictFarMonths(current);
      if (changedDate != null) {
        final changedMonth = DateTime(changedDate.year, changedDate.month);
        for (final month in _reports.cachedDailyBalanceMonths()) {
          if (month == changedMonth) {
            // Its saldo is refetched by dailyBalanceProvider itself (every
            // write invalidates it / changes the queue it watches).
            await _prefetchMonth(month, includeBalance: false, force: true);
          } else if (month.isAfter(changedMonth)) {
            await _reports.dailyBalance(year: month.year, month: month.month);
          }
        }
        return;
      }
      if (!force &&
          _lastFullRefresh != null &&
          now.difference(_lastFullRefresh!) < _refreshThrottle) {
        return;
      }
      _lastFullRefresh = now;
      await _prefetchAccountsAndTags(force: true);
      final months = {
        ..._reports.cachedDailyBalanceMonths(),
        DateTime(current.year, current.month - 1),
        current,
        DateTime(current.year, current.month + 1),
      };
      for (final month in months) {
        await _prefetchMonth(month, force: true);
      }
    } catch (error) {
      if (isOfflineError(error)) _connectivity.markOffline();
    }
  }

  void _evictFarMonths(DateTime current) {
    for (final month in _reports.cachedDailyBalanceMonths()) {
      final distance =
          ((month.year - current.year) * 12 + month.month - current.month)
              .abs();
      if (distance > _maxCachedMonthDistance) _reports.removeCachedMonth(month);
    }
  }
}

FinTransaction _copyWithId(FinTransaction t, String id) => FinTransaction(
  id: id,
  accountId: t.accountId,
  type: t.type,
  amount: t.amount,
  date: t.date,
  categoryId: t.categoryId,
  description: t.description,
  counterpartAccountId: t.counterpartAccountId,
);
