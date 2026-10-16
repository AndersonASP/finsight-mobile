/// Build-time configuration. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=https://your-api.example.com
class Env {
  Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
