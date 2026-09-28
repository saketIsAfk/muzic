class ApiConfig {
  // Compile-time override: flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
  // No flag passed -> defaults to the deployed backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://muzic-server-production.up.railway.app',
  );
}
