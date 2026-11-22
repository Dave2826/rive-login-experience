import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/platillo.dart';

class ProductService {
  final http.Client _client;

  ProductService({http.Client? client}) : _client = client ?? http.Client();

  /// Obtiene la lista de platillos desde el backend Spring Boot.
  ///
  /// Requiere el token JWT para la cabecera `Authorization: Bearer <token>`.
  Future<List<Platillo>> getProducts(String token) async {
    try {
      final response = await _client
          .get(
            ApiConfig.platillosUri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (decoded is! List) {
          throw const FormatException(
            'No se pudo interpretar la respuesta del catálogo.',
          );
        }

        final platillos = <Platillo>[];

        for (final item in decoded) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'No se pudo interpretar la respuesta del catálogo.',
            );
          }

          platillos.add(Platillo.fromJson(item));
        }

        return platillos;
      } else if (response.statusCode == 401) {
        throw const HttpException('Sesión no autorizada o token inválido.');
      } else if (response.statusCode >= 500) {
        throw const HttpException(
          'Error interno en el servidor al cargar los platillos.',
        );
      } else {
        throw HttpException(
          'Error del servidor al obtener platillos (${response.statusCode}).',
        );
      }
    } on SocketException {
      throw const SocketException('No fue posible conectar con el servidor.');
    } on TimeoutException {
      throw TimeoutException(
        'Tiempo de espera agotado al conectar con el servidor.',
      );
    } on FormatException {
      throw const FormatException(
        'No se pudo interpretar la respuesta del catálogo.',
      );
    }
  }
}
