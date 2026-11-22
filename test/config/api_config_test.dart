import 'package:flutter_test/flutter_test.dart';
import 'package:login_drive_animation/config/api_config.dart';

// Valor esperado cuando la compilación recibe:
//   --dart-define=API_BASE_URL=http://127.0.0.1:9999
//   --dart-define=EXPECTED_API_BASE_URL=http://127.0.0.1:9999
const String _expectedOverride = String.fromEnvironment(
  'EXPECTED_API_BASE_URL',
);

void main() {
  group('ApiConfig', () {
    test('baseUrl usa el valor por defecto o el override compilado', () {
      if (_expectedOverride.isEmpty) {
        expect(ApiConfig.baseUrl, 'http://10.0.2.2:8080');
      } else {
        expect(ApiConfig.baseUrl, _expectedOverride);
      }
    });

    test('baseUrl es una URL absoluta sin barra final', () {
      final uri = Uri.parse(ApiConfig.baseUrl);

      expect(uri.hasScheme, isTrue);
      expect(uri.scheme, anyOf('http', 'https'));
      expect(uri.host, isNotEmpty);
      expect(ApiConfig.baseUrl.endsWith('/'), isFalse);
    });

    test('loginUri apunta a /auth/login', () {
      expect(ApiConfig.loginUri, Uri.parse('${ApiConfig.baseUrl}/auth/login'));
      expect(ApiConfig.loginUri.path, '/auth/login');
      expect(ApiConfig.loginUri.path.startsWith('//'), isFalse);
    });

    test('platillosUri apunta a /api/platillos', () {
      expect(
        ApiConfig.platillosUri,
        Uri.parse('${ApiConfig.baseUrl}/api/platillos'),
      );
      expect(ApiConfig.platillosUri.path, '/api/platillos');
      expect(ApiConfig.platillosUri.path.startsWith('//'), isFalse);
    });

    test('las URIs derivadas comparten host y puerto de baseUrl', () {
      final base = Uri.parse(ApiConfig.baseUrl);

      for (final uri in [ApiConfig.loginUri, ApiConfig.platillosUri]) {
        expect(uri.scheme, base.scheme);
        expect(uri.host, base.host);
        expect(uri.port, base.port);
      }
    });
  });
}
