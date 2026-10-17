import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main.dart with a [SharedPreferences]-backed store once the
/// plugin is ready; the default (used by widget tests) lives in memory only.
final offlineStoreProvider = Provider<OfflineStore>((ref) {
  return OfflineStore.memory();
});

/// Last-known server responses (and the queue of not-yet-synced lançamentos)
/// kept on the device so the Saldos tab keeps working without a connection.
///
/// Values are stored as the raw JSON the API returned — each repository
/// parses them with the same `fromJson` it uses for a live response. Reads
/// are synchronous: [SharedPreferences] keeps everything in memory after
/// `getInstance()`, and writes update that copy immediately.
class OfflineStore {
  OfflineStore(SharedPreferences prefs) : _prefs = prefs;

  OfflineStore.memory() : _prefs = null;

  final SharedPreferences? _prefs;
  final Map<String, String> _memory = {};

  static const _prefix = 'offline.';

  Object? read(String key) {
    final raw = _prefs != null
        ? _prefs.getString('$_prefix$key')
        : _memory['$_prefix$key'];
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null; // a corrupt entry is treated as "nothing cached"
    }
  }

  void write(String key, Object? value) {
    final encoded = jsonEncode(value);
    if (_prefs != null) {
      _prefs.setString('$_prefix$key', encoded);
    } else {
      _memory['$_prefix$key'] = encoded;
    }
  }

  void remove(String key) {
    if (_prefs != null) {
      _prefs.remove('$_prefix$key');
    } else {
      _memory.remove('$_prefix$key');
    }
  }

  /// Keys (without the internal prefix) that start with [prefix].
  Iterable<String> keysStartingWith(String prefix) {
    final full = '$_prefix$prefix';
    final keys = _prefs != null ? _prefs.getKeys() : _memory.keys;
    return keys
        .where((k) => k.startsWith(full))
        .map((k) => k.substring(_prefix.length))
        .toList();
  }

  /// Wipes every cached response and the pending queue — used on sign-out
  /// so the next account to log in never sees (or syncs) the previous one's data.
  Future<void> clear() async {
    for (final key in keysStartingWith('')) {
      remove(key);
    }
  }
}

String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
