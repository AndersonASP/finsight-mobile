import 'package:dio/dio.dart';
import '../env/env.dart';
import '../offline/connectivity.dart';
import '../storage/token_storage.dart';

/// Builds the shared Dio instance used by every repository.
///
/// Attaches the stored access token to every request and, on a 401, attempts
/// a single silent refresh via `/auth/refresh` before retrying the original
/// request. If the refresh itself fails, [onSessionExpired] is invoked so the
/// app can route back to the login screen.
Dio buildApiClient({
  required TokenStorage tokenStorage,
  required void Function() onSessionExpired,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.readAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isUnauthorized = error.response?.statusCode == 401;
        final isRefreshCall = error.requestOptions.path.contains(
          '/auth/refresh',
        );

        if (!isUnauthorized || isRefreshCall) {
          handler.next(error);
          return;
        }

        final refreshToken = await tokenStorage.readRefreshToken();
        if (refreshToken == null) {
          await tokenStorage.clear();
          onSessionExpired();
          handler.next(error);
          return;
        }

        try {
          final refreshDio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
          final response = await refreshDio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          final newAccessToken = response.data['accessToken'] as String;
          await tokenStorage.saveAccessToken(newAccessToken);

          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await dio.fetch(retryOptions);
          handler.resolve(retryResponse);
        } catch (refreshError) {
          // Only a refresh the server actually rejected ends the session —
          // losing the connection mid-refresh mustn't log the user out (and
          // wipe their offline data along with it).
          if (!isOfflineError(refreshError)) {
            await tokenStorage.clear();
            onSessionExpired();
          }
          handler.next(error);
        }
      },
    ),
  );

  return dio;
}
