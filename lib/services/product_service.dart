
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductService {
  static const String baseUrl = 'http://10.0.2.2:8080';

  Future<List<dynamic>> getProducts() async {
    final url = Uri.parse('$baseUrl/products');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      return data as List<dynamic>;
    } else {
      throw Exception(
        'Error al obtener productos: ${response.statusCode}',
      );
    }
  }
}
