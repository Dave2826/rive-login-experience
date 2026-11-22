import 'package:flutter_test/flutter_test.dart';
import 'package:login_drive_animation/models/auth_models.dart';

void main() {
  group('LoginRequest', () {
    test('toJson incluye username y password', () {
      const request = LoginRequest(username: 'admin', password: '1234');

      expect(request.toJson(), <String, dynamic>{
        'username': 'admin',
        'password': '1234',
      });
    });
  });

  group('AuthResponse', () {
    test('fromJson lee el token de la respuesta', () {
      final response = AuthResponse.fromJson(<String, dynamic>{
        'token': 'jwt-de-prueba',
      });

      expect(response.token, 'jwt-de-prueba');
    });

    test('fromJson devuelve token vacío cuando la clave no existe', () {
      final response = AuthResponse.fromJson(<String, dynamic>{});

      expect(response.token, isEmpty);
    });

    test('fromJson devuelve token vacío cuando el valor es nulo', () {
      final response = AuthResponse.fromJson(<String, dynamic>{'token': null});

      expect(response.token, isEmpty);
    });

    test('toJson devuelve el token', () {
      const response = AuthResponse(token: 'jwt-de-prueba');

      expect(response.toJson(), <String, dynamic>{'token': 'jwt-de-prueba'});
    });
  });
}
