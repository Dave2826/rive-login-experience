import 'package:flutter_test/flutter_test.dart';
import 'package:login_drive_animation/models/platillo.dart';

void main() {
  group('Platillo.fromJson', () {
    test('deserializa un JSON completo', () {
      final platillo = Platillo.fromJson(<String, dynamic>{
        'id': 7,
        'nombre': 'Tacos al pastor',
        'descripcion': 'Tortillas de maíz con carne de cerdo.',
        'precio': 95.5,
        'categoria': 'Tacos',
        'disponible': true,
      });

      expect(platillo.id, 7);
      expect(platillo.nombre, 'Tacos al pastor');
      expect(platillo.descripcion, 'Tortillas de maíz con carne de cerdo.');
      expect(platillo.precio, 95.5);
      expect(platillo.categoria, 'Tacos');
      expect(platillo.disponible, isTrue);
    });

    test('acepta descripcion y categoria nulas', () {
      final platillo = Platillo.fromJson(<String, dynamic>{
        'id': 3,
        'nombre': 'Agua de horchata',
        'descripcion': null,
        'precio': 35.0,
        'categoria': null,
        'disponible': true,
      });

      expect(platillo.descripcion, isNull);
      expect(platillo.categoria, isNull);
    });

    test('convierte un precio entero a double', () {
      final platillo = Platillo.fromJson(<String, dynamic>{
        'id': 1,
        'nombre': 'Hamburguesa',
        'precio': 180,
        'disponible': true,
      });

      expect(platillo.precio, 180.0);
      expect(platillo.precio, isA<double>());
    });

    test('conserva un precio decimal', () {
      final platillo = Platillo.fromJson(<String, dynamic>{
        'id': 2,
        'nombre': 'Pizza',
        'precio': 180.25,
        'disponible': true,
      });

      expect(platillo.precio, 180.25);
    });

    test('marca como no disponible cuando disponible es false', () {
      final platillo = Platillo.fromJson(<String, dynamic>{
        'id': 4,
        'nombre': 'Ensalada',
        'precio': 90.0,
        'disponible': false,
      });

      expect(platillo.disponible, isFalse);
    });

    test('marca como disponible cuando disponible es true', () {
      final platillo = Platillo.fromJson(<String, dynamic>{
        'id': 5,
        'nombre': 'Sopa',
        'precio': 70.0,
        'disponible': true,
      });

      expect(platillo.disponible, isTrue);
    });
  });

  group('Platillo.toJson', () {
    test('incluye todos los campos cuando descripcion y categoria existen', () {
      const platillo = Platillo(
        id: 7,
        nombre: 'Tacos al pastor',
        descripcion: 'Tortillas de maíz',
        precio: 95.5,
        categoria: 'Tacos',
        disponible: true,
      );

      expect(platillo.toJson(), <String, dynamic>{
        'id': 7,
        'nombre': 'Tacos al pastor',
        'descripcion': 'Tortillas de maíz',
        'precio': 95.5,
        'categoria': 'Tacos',
        'disponible': true,
      });
    });

    test('omite descripcion y categoria cuando son nulas', () {
      const platillo = Platillo(
        id: 8,
        nombre: 'Agua',
        precio: 20.0,
        disponible: false,
      );

      final json = platillo.toJson();

      expect(json.containsKey('descripcion'), isFalse);
      expect(json.containsKey('categoria'), isFalse);
      expect(json['id'], 8);
      expect(json['nombre'], 'Agua');
      expect(json['precio'], 20.0);
      expect(json['disponible'], isFalse);
    });
  });
}
