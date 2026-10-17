import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when [error] means the server couldn't be reached at all (no
/// network, DNS failure, timeout) — as opposed to the server answering with
/// an error, which offline mode must never paper over.
bool isOfflineError(Object error) {
  if (error is OfflineException) return true;
  if (error is SocketException) return true;
  if (error is! DioException) return false;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.unknown => error.response == null,
    _ => false,
  };
}

/// Thrown when there's no connection *and* nothing cached to fall back on,
/// or when an action needs the server (e.g. creating a recurring series).
class OfflineException implements Exception {
  const OfflineException([
    this.message = 'Sem conexão e nenhum dado salvo neste aparelho ainda.',
  ]);

  final String message;

  @override
  String toString() => message;
}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

/// Whether the API is currently believed unreachable (`true` = offline).
///
/// Flipped by real request outcomes rather than an OS network listener: a
/// phone can be "on Wi-Fi" and still not reach the API. While offline,
/// reads skip the network and go straight to the cache (so the UI doesn't
/// sit through a connect timeout on every screen), and [SyncService] keeps
/// probing until a request succeeds again.
class ConnectivityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  bool get isOffline => state;

  void markOffline() {
    if (!state) state = true;
  }

  void markOnline() {
    if (state) state = false;
  }
}

/// Runs [network]; if the API can't be reached, falls back to [cache].
///
/// While already known to be offline, [cache] is tried first so screens open
/// instantly — the network is only attempted when nothing is cached.
Future<T> networkOrCache<T>(
  Ref ref, {
  required Future<T> Function() network,
  required T? Function() cache,
}) async {
  final connectivity = ref.read(connectivityProvider.notifier);
  if (connectivity.isOffline) {
    final cached = cache();
    if (cached != null) return cached;
  }
  try {
    final result = await network();
    connectivity.markOnline();
    return result;
  } catch (error) {
    if (!isOfflineError(error)) rethrow;
    connectivity.markOffline();
    final cached = cache();
    if (cached != null) return cached;
    throw const OfflineException();
  }
}
