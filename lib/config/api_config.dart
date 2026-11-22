class ApiConfig {
  ApiConfig._();

  /// URL base para acceder al backend Spring Boot.
  ///
  /// El valor por defecto apunta al equipo anfitrión desde el emulador Android.
  /// Para usar otra máquina o un dispositivo físico:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Endpoint de autenticación (POST /auth/login)
  static const String loginEndpoint = '/auth/login';

  /// Endpoint de catálogo de platillos (GET /api/platillos)
  static const String platillosEndpoint = '/api/platillos';

  /// URI completa para inicio de sesión
  static Uri get loginUri => Uri.parse('$baseUrl$loginEndpoint');

  /// URI completa para el catálogo de platillos
  static Uri get platillosUri => Uri.parse('$baseUrl$platillosEndpoint');
}
