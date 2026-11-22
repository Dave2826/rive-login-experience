import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login_drive_animation/config/api_config.dart';
import 'package:login_drive_animation/models/platillo.dart';
import 'package:login_drive_animation/services/api_exceptions.dart';
import 'package:login_drive_animation/services/product_service.dart';

const String _token = 'jwt-de-prueba';

const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

const List<Map<String, Object?>> _platillosJson = <Map<String, Object?>>[
  <String, Object?>{
    'id': 1,
    'nombre': 'Hamburguesa Clásica',
    'descripcion': 'Carne de res con queso, lechuga y tomate.',
    'precio': 180.0,
    'categoria': 'Hamburguesas',
    'disponible': true,
  },
  <String, Object?>{
    'id': 2,
    'nombre': 'Agua de horchata',
    'descripcion': null,
    'precio': 35,
    'categoria': null,
    'disponible': false,
  },
];

ProductService _serviceWith(MockClient client) =>
    ProductService(client: client);

void main() {
  group('ProductService.getProducts · solicitud', () {
    test('envía GET a /api/platillos con accept y bearer', () async {
      late http.Request captured;

      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<Map<String, Object?>>[]),
          200,
          headers: _jsonHeaders,
        );
      });

      await _serviceWith(client).getProducts(_token);

      expect(captured.method, 'GET');
      expect(captured.url, ApiConfig.platillosUri);
      expect(captured.headers['accept'], 'application/json');
      expect(captured.headers['authorization'], 'Bearer $_token');
    });
  });

  group('ProductService.getProducts · respuestas exitosas', () {
    test('mapea una lista válida a Platillo', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(_platillosJson),
          200,
          headers: _jsonHeaders,
        ),
      );

      final platillos = await _serviceWith(client).getProducts(_token);

      expect(platillos, hasLength(2));
      expect(platillos.first, isA<Platillo>());
      expect(platillos.first.id, 1);
      expect(platillos.first.nombre, 'Hamburguesa Clásica');
      expect(platillos.first.precio, 180.0);
      expect(platillos.first.disponible, isTrue);
      expect(platillos.last.id, 2);
      expect(platillos.last.descripcion, isNull);
      expect(platillos.last.categoria, isNull);
      expect(platillos.last.precio, 35.0);
      expect(platillos.last.disponible, isFalse);
    });

    test(
      'devuelve una lista vacía cuando el backend no tiene platillos',
      () async {
        final client = MockClient(
          (_) async => http.Response('[]', 200, headers: _jsonHeaders),
        );

        final platillos = await _serviceWith(client).getProducts(_token);

        expect(platillos, isEmpty);
      },
    );

    test('decodifica correctamente caracteres acentuados en UTF-8', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'id': 9,
              'nombre': 'Piña colada',
              'descripcion': 'Bebida con piña, coco y limón.',
              'precio': 65.5,
              'categoria': 'Bebidas',
              'disponible': true,
            },
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );

      final platillos = await _serviceWith(client).getProducts(_token);

      expect(platillos.single.nombre, 'Piña colada');
      expect(platillos.single.descripcion, 'Bebida con piña, coco y limón.');
      expect(platillos.single.categoria, 'Bebidas');
    });
  });

  group('ProductService.getProducts · respuestas inválidas', () {
    test('un objeto en lugar de lista lanza FormatException', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{'error': 'no es una lista'}),
          200,
          headers: _jsonHeaders,
        ),
      );

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('catálogo'),
          ),
        ),
      );
    });

    test('una lista con un elemento no objeto lanza FormatException', () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode(<Object?>[1]), 200, headers: _jsonHeaders),
      );

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('catálogo'),
          ),
        ),
      );
    });

    test('un JSON inválido lanza FormatException', () async {
      final client = MockClient(
        (_) async =>
            http.Response('<html>error</html>', 200, headers: _jsonHeaders),
      );

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('catálogo'),
          ),
        ),
      );
    });
  });

  group('ProductService.getProducts · errores HTTP', () {
    test('HTTP 401 señala token inválido', () async {
      final client = MockClient((_) async => http.Response('{}', 401));

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            contains('no autorizada'),
          ),
        ),
      );
    });

    test('HTTP 500 señala error interno del servidor', () async {
      final client = MockClient((_) async => http.Response('{}', 500));

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('Error interno'),
          ),
        ),
      );
    });

    test('HTTP 400 incluye el código en el mensaje', () async {
      final client = MockClient((_) async => http.Response('{}', 400));

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('400'),
          ),
        ),
      );
    });
  });

  group('ProductService.getProducts · fallos de red', () {
    test('TimeoutException se propaga', () async {
      final client = MockClient(
        (_) async => throw TimeoutException('simulado'),
      );

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            contains('Tiempo de espera'),
          ),
        ),
      );
    });

    test('SocketException se propaga como fallo de conexión', () async {
      final client = MockClient(
        (_) async => throw const SocketException('conexión rechazada'),
      );

      await expectLater(
        _serviceWith(client).getProducts(_token),
        throwsA(
          isA<SocketException>().having(
            (e) => e.message,
            'message',
            contains('No fue posible'),
          ),
        ),
      );
    });
  });
}
