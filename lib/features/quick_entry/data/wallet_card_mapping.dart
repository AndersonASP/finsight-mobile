import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/offline/offline_store.dart';

/// A card in the iPhone's Wallet linked to a FinSight card (crédito) or
/// account (débito) — where an Apple Pay purchase made with it is logged.
class WalletCardMapping {
  const WalletCardMapping({
    required this.id,
    required this.walletName,
    this.cardId,
    this.cardName,
    this.accountId,
    this.accountName,
  });

  final String id;

  /// Normalized (lowercase) as stored by the API.
  final String walletName;
  final String? cardId;
  final String? cardName;
  final String? accountId;
  final String? accountName;

  bool get isCredit => cardId != null;
  String get targetName => cardName ?? accountName ?? '';

  factory WalletCardMapping.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map?;
    final account = json['account'] as Map?;
    return WalletCardMapping(
      id: json['id'] as String,
      walletName: json['walletName'] as String,
      cardId: json['cardId'] as String?,
      cardName: card?['name'] as String?,
      accountId: json['accountId'] as String?,
      accountName: account?['name'] as String?,
    );
  }
}

final walletMappingsRepositoryProvider = Provider<WalletMappingsRepository>((
  ref,
) {
  return WalletMappingsRepository(
    ref.watch(dioProvider),
    ref.watch(offlineStoreProvider),
  );
});

class WalletMappingsRepository {
  WalletMappingsRepository(this._dio, this._store);

  final Dio _dio;
  final OfflineStore _store;

  static const _cacheKey = 'walletMappings';

  /// Cached so a pre-filled form (opened when an automation ran offline)
  /// still knows which card or account the Wallet card stands for.
  Future<List<WalletCardMapping>> list() async {
    final response = await _dio.get('/quick-entries/mappings');
    _store.write(_cacheKey, response.data);
    return _parse(response.data as List);
  }

  List<WalletCardMapping>? cachedList() {
    final cached = _store.read(_cacheKey);
    return cached is List ? _parse(cached) : null;
  }

  Future<void> save({
    required String walletName,
    String? cardId,
    String? accountId,
  }) async {
    await _dio.put(
      '/quick-entries/mappings',
      data: {
        'walletName': walletName,
        'cardId': ?cardId,
        'accountId': ?accountId,
      },
    );
  }

  Future<void> delete(String id) => _dio.delete('/quick-entries/mappings/$id');

  static List<WalletCardMapping> _parse(List data) => data
      .map(
        (json) => WalletCardMapping.fromJson(Map<String, dynamic>.from(json)),
      )
      .toList();
}

/// Mirrors the API's normalization, for matching against cached mappings.
String normalizeWalletName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
