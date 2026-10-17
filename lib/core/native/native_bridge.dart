import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../env/env.dart';

/// A purchase an Apple Pay automation couldn't log by itself (offline, or a
/// Wallet card not linked yet) — the app opens a pre-filled form for it.
class PendingQuickEntry {
  const PendingQuickEntry({
    required this.amount,
    required this.merchant,
    this.cardName,
    this.date,
  });

  /// API-style decimal ("26.00").
  final String amount;
  final String merchant;
  final String? cardName;
  final DateTime? date;

  static PendingQuickEntry? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final amount = map['amount'] as String?;
    final merchant = map['merchant'] as String?;
    if (amount == null || merchant == null) return null;
    return PendingQuickEntry(
      amount: amount,
      merchant: merchant,
      cardName: map['cardName'] as String?,
      date: DateTime.tryParse(map['date'] as String? ?? ''),
    );
  }
}

/// The iOS side (App Intents for Shortcuts / Apple Pay) can't read the
/// Flutter-encrypted keychain, so the session is mirrored to it here. All
/// calls are best effort: off iOS, in tests or on an old build, they no-op.
class NativeBridge {
  static const _channel = MethodChannel('dev.andalsp.finsight/native');

  static Future<void> setSession({String? accessToken, String? refreshToken}) =>
      _call('setSession', {
        'apiBaseUrl': Env.apiBaseUrl,
        'accessToken': ?accessToken,
        'refreshToken': ?refreshToken,
      });

  static Future<void> clearSession() => _call('clearSession');

  /// The entry left by the last automation that needed the app, if any
  /// (consumed: a second call returns null).
  static Future<PendingQuickEntry?> takePendingQuickEntry() async {
    final result = await _call('takePendingQuickEntry');
    return result is Map ? PendingQuickEntry.fromMap(result) : null;
  }

  static Future<Object?> _call(String method, [Object? arguments]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('Native bridge $method failed: $error');
      return null;
    }
  }
}
