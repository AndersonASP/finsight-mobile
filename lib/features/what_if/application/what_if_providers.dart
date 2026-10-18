import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/reminder_notifications.dart';
import '../../../core/offline/offline_store.dart';
import '../data/what_if.dart';
import '../data/what_if_repository.dart';

/// "Quero comprar", each item re-simulated by the server today.
final wishlistProvider = FutureProvider.autoDispose<List<WishlistItem>>((ref) {
  return ref.watch(whatIfRepositoryProvider).wishlist();
});

final wishlistWatcherProvider = Provider<WishlistWatcher>((ref) {
  return WishlistWatcher(ref);
});

/// Remembers each item's last verdict on the device and, on sync, notifies
/// when one moves to "cabe" — the purchase now fits without breaking the
/// savings target. An item seen for the first time never notifies.
class WishlistWatcher {
  WishlistWatcher(this._ref);

  final Ref _ref;

  static const _storeKey = 'wishlist.verdicts';

  /// Items that just turned "cabe", given the previous verdicts; also
  /// returns the verdicts to remember from now on.
  static (List<WishlistItem>, Map<String, String>) transitions(
    Map<String, String> previous,
    List<WishlistItem> items,
  ) {
    final nowFits = <WishlistItem>[];
    final next = <String, String>{};
    for (final item in items) {
      final verdict = item.simulacao.verdict.name;
      next[item.id] = verdict;
      final before = previous[item.id];
      if (before != null &&
          before != WhatIfVerdict.cabe.name &&
          item.simulacao.verdict == WhatIfVerdict.cabe) {
        nowFits.add(item);
      }
    }
    return (nowFits, next);
  }

  /// Records [items]' verdicts without notifying (after the user looked at them).
  void remember(List<WishlistItem> items) {
    final store = _ref.read(offlineStoreProvider);
    store.write(_storeKey, {
      for (final item in items) item.id: item.simulacao.verdict.name,
    });
  }

  Future<void> check() async {
    final store = _ref.read(offlineStoreProvider);
    final List<WishlistItem> items;
    try {
      items = await _ref.read(whatIfRepositoryProvider).wishlist();
    } catch (_) {
      return; // offline or server trouble: try again on the next sync
    }
    final raw = store.read(_storeKey);
    final previous = raw is Map
        ? raw.map((k, v) => MapEntry(k as String, v as String))
        : <String, String>{};
    final (nowFits, next) = transitions(previous, items);
    store.write(_storeKey, next);

    final notifications = _ref.read(reminderNotificationsProvider);
    for (final item in nowFits) {
      await notifications.showNow(
        id: 900000 + item.id.hashCode.abs() % 100000,
        title: '${item.description} agora cabe',
        body: item.simulacao.manchete,
      );
    }
  }
}
