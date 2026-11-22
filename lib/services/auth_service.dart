import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/auth_models.dart';

/// Excepción personalizada para errores del flujo de autenticación.
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  const AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Servicio encargado de la comunicación HTTP para autenticación contra Spring Boot.
class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Realiza la autenticación mediante POST /auth/login.
  ///
  /// Recibe un [LoginRequest] con username y password.
  /// Devuelve un [AuthResponse] con el token JWT si la autenticación es exitosa.
  /// Lanza [AuthException] en caso de credenciales inválidas (401), errores de servidor o fallos de red.
  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _client
          .post(
            ApiConfig.loginUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        final authResponse = AuthResponse.fromJson(data);

        if (authResponse.token.isEmpty) {
          throw const AuthException(
            'Respuesta del servidor sin token de autenticación.',
          );
        }

        return authResponse;
      } else if (response.statusCode == 401) {
        throw const AuthException(
          'Credenciales de acceso inválidas.',
          statusCode: 401,
        );
      } else {
        throw AuthException(
          'Error del servidor al iniciar sesión (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw const AuthException(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    } on TimeoutException {
      throw const AuthException(
        'El servidor tardó demasiado en responder. Inténtalo más tarde.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Error de comunicación de red al conectar con el servidor.',
      );
    } on FormatException {
      throw const AuthException(
        'Formato de respuesta del servidor no reconocido.',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Error inesperado durante la autenticación: $e');
    }
  }
}
