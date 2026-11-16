import 'dart:convert';

import 'package:http/http.dart' as http;

class ProductService {
  // URL base configurable en tiempo de compilación:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
  // Si no se define, se conserva el valor por defecto para el emulador Android.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  Future<List<dynamic>> getProducts() async {
    final url = Uri.parse('$baseUrl/products');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      return data as List<dynamic>;
    } else {
      throw Exception('Error al obtener productos: ${response.statusCode}');
    }
  }
}
