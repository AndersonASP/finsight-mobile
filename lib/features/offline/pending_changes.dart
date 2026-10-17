import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/offline_store.dart';
import '../transactions/data/fin_transaction.dart';

/// Ids given to lançamentos created offline, until the server assigns a real one.
bool isLocalTransactionId(String id) => id.startsWith('local-');

String newLocalTransactionId() {
  final random = Random();
  final suffix = List.generate(
    12,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  return 'local-${DateTime.now().microsecondsSinceEpoch}-$suffix';
}

class PendingUpdate {
  const PendingUpdate({required this.before, required this.after});

  /// The server's version (what the cached Saldos/day detail still reflect).
  final FinTransaction before;
  final FinTransaction after;

  Map<String, dynamic> toJson() => {
    'before': before.toJson(),
    'after': after.toJson(),
  };

  factory PendingUpdate.fromJson(Map<String, dynamic> json) => PendingUpdate(
    before: FinTransaction.fromJson(Map<String, dynamic>.from(json['before'])),
    after: FinTransaction.fromJson(Map<String, dynamic>.from(json['after'])),
  );
}

/// Lançamentos changed on this device that the server hasn't received yet.
///
/// Kept as net state rather than an operation log: editing an offline-created
/// lançamento just rewrites it in [creates], deleting it drops it entirely,
/// and editing a server one twice keeps its original [PendingUpdate.before].
/// That's exactly what the offline overlay needs — remove the "before"
/// effects from the cached server data, add the "after" ones.
class PendingChanges {
  const PendingChanges({
    this.creates = const {},
    this.updates = const {},
    this.deletes = const {},
  });

  /// Local id → lançamento created offline.
  final Map<String, FinTransaction> creates;

  /// Server id → edit made offline.
  final Map<String, PendingUpdate> updates;

  /// Server id → its last known server version, deleted offline.
  final Map<String, FinTransaction> deletes;

  bool get isEmpty => creates.isEmpty && updates.isEmpty && deletes.isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get count => creates.length + updates.length + deletes.length;

  /// Server versions whose effect must be taken out of cached server data.
  Iterable<FinTransaction> get removed => [
    for (final u in updates.values) u.before,
    ...deletes.values,
  ];

  /// Versions whose effect must be added on top of cached server data.
  Iterable<FinTransaction> get added => [
    ...creates.values,
    for (final u in updates.values) u.after,
  ];

  /// The current (possibly offline-edited) version of [id], if it's pending.
  FinTransaction? currentVersionOf(String id) =>
      creates[id] ?? updates[id]?.after;

  PendingChanges copyWith({
    Map<String, FinTransaction>? creates,
    Map<String, PendingUpdate>? updates,
    Map<String, FinTransaction>? deletes,
  }) => PendingChanges(
    creates: creates ?? this.creates,
    updates: updates ?? this.updates,
    deletes: deletes ?? this.deletes,
  );

  Map<String, dynamic> toJson() => {
    'creates': {for (final e in creates.entries) e.key: e.value.toJson()},
    'updates': {for (final e in updates.entries) e.key: e.value.toJson()},
    'deletes': {for (final e in deletes.entries) e.key: e.value.toJson()},
  };

  factory PendingChanges.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) =>
        Map<String, dynamic>.from(json[key] as Map? ?? const {});
    return PendingChanges(
      creates: section(
        'creates',
      ).map((k, v) => MapEntry(k, FinTransaction.fromJson(Map.from(v)))),
      updates: section(
        'updates',
      ).map((k, v) => MapEntry(k, PendingUpdate.fromJson(Map.from(v)))),
      deletes: section(
        'deletes',
      ).map((k, v) => MapEntry(k, FinTransaction.fromJson(Map.from(v)))),
    );
  }
}

final pendingChangesProvider =
    NotifierProvider<PendingChangesNotifier, PendingChanges>(
      PendingChangesNotifier.new,
    );

class PendingChangesNotifier extends Notifier<PendingChanges> {
  static const _storeKey = 'pending';

  OfflineStore get _store => ref.read(offlineStoreProvider);

  @override
  PendingChanges build() {
    final json = ref.watch(offlineStoreProvider).read(_storeKey);
    if (json is! Map) return const PendingChanges();
    try {
      return PendingChanges.fromJson(Map<String, dynamic>.from(json));
    } catch (_) {
      return const PendingChanges();
    }
  }

  void _set(PendingChanges next) {
    state = next;
    _store.write(_storeKey, next.toJson());
  }

  /// Queues a new lançamento; [transaction]'s id must be a local one.
  void create(FinTransaction transaction) {
    assert(isLocalTransactionId(transaction.id));
    _set(
      state.copyWith(creates: {...state.creates, transaction.id: transaction}),
    );
  }

  /// Queues an edit. [serverVersion] is what the server currently has — only
  /// used the first time a given lançamento is edited offline.
  void edit({
    required FinTransaction serverVersion,
    required FinTransaction updated,
  }) {
    final id = updated.id;
    if (isLocalTransactionId(id)) {
      _set(state.copyWith(creates: {...state.creates, id: updated}));
      return;
    }
    final before = state.updates[id]?.before ?? serverVersion;
    _set(
      state.copyWith(
        updates: {
          ...state.updates,
          id: PendingUpdate(before: before, after: updated),
        },
      ),
    );
  }

  /// Queues a deletion. An offline-created lançamento just disappears from
  /// the queue; a server one remembers its *server* version so its effect
  /// can still be subtracted from the cached Saldos.
  void delete(FinTransaction current) {
    final id = current.id;
    if (isLocalTransactionId(id)) {
      _set(state.copyWith(creates: {...state.creates}..remove(id)));
      return;
    }
    final updates = {...state.updates};
    final serverVersion = updates.remove(id)?.before ?? current;
    _set(
      state.copyWith(
        updates: updates,
        deletes: {...state.deletes, id: serverVersion},
      ),
    );
  }

  /// [sent] (queued as [localId]) now exists on the server as [created].
  /// If the user edited or deleted it while the request was in flight, that
  /// newer change is re-queued against the server id instead of being lost.
  void markCreateSynced(
    String localId,
    FinTransaction sent,
    FinTransaction created,
  ) {
    final creates = {...state.creates};
    final current = creates.remove(localId);
    var next = state.copyWith(creates: creates);
    if (current == null) {
      next = next.copyWith(deletes: {...next.deletes, created.id: created});
    } else if (!identical(current, sent)) {
      next = next.copyWith(
        updates: {
          ...next.updates,
          created.id: PendingUpdate(
            before: created,
            after: _withId(current, created.id),
          ),
        },
      );
    }
    _set(next);
  }

  void markUpdateSynced(String id, FinTransaction sent) {
    final pending = state.updates[id];
    if (pending == null) return;
    final updates = {...state.updates};
    if (identical(pending.after, sent)) {
      updates.remove(id);
    } else {
      // Edited again mid-flight: the server now has [sent].
      updates[id] = PendingUpdate(before: sent, after: pending.after);
    }
    _set(state.copyWith(updates: updates));
  }

  void markDeleteSynced(String id) {
    if (!state.deletes.containsKey(id)) return;
    _set(state.copyWith(deletes: {...state.deletes}..remove(id)));
  }

  /// Drops a change the server refused (e.g. its account no longer exists),
  /// so one bad item can't block the rest of the queue forever.
  void discard(String id) {
    _set(
      PendingChanges(
        creates: {...state.creates}..remove(id),
        updates: {...state.updates}..remove(id),
        deletes: {...state.deletes}..remove(id),
      ),
    );
  }

  void clear() => _set(const PendingChanges());
}

FinTransaction _withId(FinTransaction t, String id) => FinTransaction(
  id: id,
  accountId: t.accountId,
  type: t.type,
  amount: t.amount,
  date: t.date,
  categoryId: t.categoryId,
  description: t.description,
  counterpartAccountId: t.counterpartAccountId,
);
