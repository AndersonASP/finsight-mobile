import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(dioProvider)),
);

/// The user's financial goals kept by the API (`/settings`).
class SettingsRepository {
  SettingsRepository(this._dio);

  final Dio _dio;

  Future<int> reserveTargetMonths() async {
    final response = await _dio.get('/settings');
    return (response.data as Map)['reserveTargetMonths'] as int;
  }

  Future<void> setReserveTargetMonths(int months) async {
    await _dio.patch('/settings', data: {'reserveTargetMonths': months});
  }
}
