import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login_drive_animation/config/api_config.dart';
import 'package:login_drive_animation/models/auth_models.dart';
import 'package:login_drive_animation/services/auth_service.dart';

const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

const LoginRequest _request = LoginRequest(username: 'admin', password: '1234');

AuthService _serviceWith(MockClient client) => AuthService(client: client);

/// Ejecuta el login y devuelve la [AuthException] lanzada.
Future<AuthException> _captureAuthError(MockClient client) async {
  try {
    await _serviceWith(client).login(_request);
  } on AuthException catch (error) {
    return error;
  }
  fail('Se esperaba una AuthException y el login terminó con éxito.');
}

void main() {
  group('AuthService.login · solicitud', () {
    test('envía POST a /auth/login con cabeceras y body JSON', () async {
      late http.Request captured;

      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, String>{'token': 'jwt-123'}),
          200,
          headers: _jsonHeaders,
        );
      });

      final response = await _serviceWith(client).login(_request);

      expect(captured.method, 'POST');
      expect(captured.url, ApiConfig.loginUri);
      expect(captured.headers['content-type'], contains('application/json'));
      expect(captured.headers['accept'], 'application/json');
      expect(jsonDecode(captured.body), <String, dynamic>{
        'username': 'admin',
        'password': '1234',
      });
      expect(response.token, 'jwt-123');
    });
  });

  group('AuthService.login · respuestas HTTP', () {
    test('HTTP 401 se reporta como credenciales inválidas', () async {
      final client = MockClient((_) async => http.Response('{}', 401));

      final error = await _captureAuthError(client);

      expect(error.statusCode, 401);
      expect(error.message, contains('Credenciales'));
    });

    test('HTTP 500 se reporta como error del servidor', () async {
      final client = MockClient((_) async => http.Response('{}', 500));

      final error = await _captureAuthError(client);

      expect(error.statusCode, 500);
      expect(error.message, contains('500'));
    });

    test('HTTP 200 sin token se rechaza', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{}),
          200,
          headers: _jsonHeaders,
        ),
      );

      final error = await _captureAuthError(client);

      expect(error.statusCode, isNull);
      expect(error.message, contains('token'));
    });

    test(
      'HTTP 200 con JSON inválido se reporta como formato no reconocido',
      () async {
        final client = MockClient(
          (_) async =>
              http.Response('esto-no-es-json', 200, headers: _jsonHeaders),
        );

        final error = await _captureAuthError(client);

        expect(error.message, contains('Formato'));
      },
    );
  });

  group('AuthService.login · fallos de red', () {
    test('TimeoutException se reporta como tiempo de espera agotado', () async {
      final client = MockClient(
        (_) async => throw TimeoutException('simulado'),
      );

      final error = await _captureAuthError(client);

      expect(error.statusCode, isNull);
      expect(error.message, contains('tardó demasiado'));
    });

    test('SocketException se reporta como fallo de conexión', () async {
      final client = MockClient(
        (_) async => throw const SocketException('conexión rechazada'),
      );

      final error = await _captureAuthError(client);

      expect(error.statusCode, isNull);
      expect(error.message, contains('No se pudo conectar'));
    });

    test(
      'http.ClientException se reporta como error de comunicación',
      () async {
        final client = MockClient(
          (_) async => throw http.ClientException('fallo de transporte'),
        );

        final error = await _captureAuthError(client);

        expect(error.statusCode, isNull);
        expect(error.message, contains('comunicación'));
      },
    );

    test('un error inesperado se envuelve en AuthException', () async {
      final client = MockClient((_) async => throw StateError('inesperado'));

      final error = await _captureAuthError(client);

      expect(error.statusCode, isNull);
      expect(error.message, contains('inesperado'));
    });
  });

  group('AuthService.loginWithFirebase · respuesta', () {
    Future<AuthException> captureFirebaseError(MockClient client) async {
      try {
        await _serviceWith(client).loginWithFirebase('id-token-de-prueba');
      } on AuthException catch (error) {
        return error;
      }
      fail('Se esperaba una AuthException y el login terminó con éxito.');
    }

    test('envía POST a /auth/firebase con el idToken', () async {
      late http.Request captured;

      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, String>{'token': 'jwt-backend'}),
          200,
          headers: _jsonHeaders,
        );
      });

      await _serviceWith(client).loginWithFirebase('id-token-de-prueba');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/auth/firebase');
      expect(captured.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(captured.body), <String, dynamic>{
        'idToken': 'id-token-de-prueba',
      });
    });

    test('HTTP 200 devuelve el JWT del backend', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{'token': 'jwt-backend'}),
          200,
          headers: _jsonHeaders,
        ),
      );

      final response = await _serviceWith(client).loginWithFirebase('id-token');

      expect(response.token, 'jwt-backend');
    });

    test('HTTP 401 se reporta como credenciales inválidas', () async {
      final client = MockClient((_) async => http.Response('{}', 401));

      final error = await captureFirebaseError(client);

      expect(error.statusCode, 401);
      expect(error.message, contains('Credenciales'));
    });

    test('HTTP 403 propaga el mensaje seguro del servidor', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'status': 403,
            'message': 'El correo de la cuenta no esta verificado',
          }),
          403,
          headers: _jsonHeaders,
        ),
      );

      final error = await captureFirebaseError(client);

      expect(error.statusCode, 403);
      expect(error.message, contains('no esta verificado'));
    });

    test('HTTP 503 informa que Firebase no está habilitado', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'status': 503,
            'message': 'La autenticación con Firebase no está habilitada en el servidor',
          }),
          503,
          headers: _jsonHeaders,
        ),
      );

      final error = await captureFirebaseError(client);

      expect(error.statusCode, 503);
      expect(error.message, contains('Firebase'));
    });

    test('SocketException se reporta como fallo de conexión', () async {
      final client = MockClient(
        (_) async => throw const SocketException('sin red'),
      );

      final error = await captureFirebaseError(client);

      expect(error.message, contains('conectar'));
    });
  });

  group('AuthException', () {
    test('toString devuelve el mensaje', () {
      const error = AuthException('fallo', statusCode: 401);

      expect(error.toString(), 'fallo');
      expect(error.statusCode, 401);
    });
  });
}
