import 'package:flutter/material.dart';

import '../models/platillo.dart';
import '../services/product_service.dart';

class ProductsScreen extends StatefulWidget {
  final String token;

  const ProductsScreen({super.key, required this.token});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService productService = ProductService();

  late Future<List<Platillo>> productsFuture;

  @override
  void initState() {
    super.initState();
    productsFuture = productService.getProducts(widget.token);
  }

  // Recarga la petición del catálogo y espera su resolución para RefreshIndicator.
  Future<void> _loadProducts() async {
    setState(() {
      productsFuture = productService.getProducts(widget.token);
    });
    try {
      await productsFuture;
    } catch (_) {
      // Ignora la excepción aquí; FutureBuilder se encarga de renderizar el error.
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error == null) {
      return 'No se pudieron cargar los platillos.\nVerifica tu conexión e inténtalo de nuevo.';
    }
    final str = error.toString();
    if (str.contains('401') || str.contains('Sesión no autorizada')) {
      return 'Sesión no autorizada o token inválido.\nVuelve a iniciar sesión.';
    }
    if (str.contains('500') || str.contains('Error interno')) {
      return 'Error interno del servidor al cargar el menú.\nInténtalo más tarde.';
    }
    if (str.contains('SocketException') || str.contains('conectar')) {
      return 'No fue posible conectar con el servidor.\nVerifica tu conexión e inténtalo de nuevo.';
    }
    if (str.contains('TimeoutException') || str.contains('agotado')) {
      return 'Tiempo de espera agotado al conectar con el servidor.\nInténtalo más tarde.';
    }
    if (str.contains('FormatException') || str.contains('interpretar')) {
      return 'No se pudo interpretar la respuesta del catálogo.';
    }
    return 'No se pudieron cargar los platillos.\nVerifica tu conexión e inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú de Platillos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Platillo>>(
        future: productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      _getErrorMessage(snapshot.error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _loadProducts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final platillos = snapshot.data ?? [];

          if (platillos.isEmpty) {
            return RefreshIndicator(
              onRefresh: _loadProducts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  const Center(
                    child: Text(
                      'No hay platillos disponibles',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadProducts,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: platillos.length,
              itemBuilder: (context, index) {
                final platillo = platillos[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(
                        platillo.nombre.isNotEmpty
                            ? platillo.nombre
                            : 'Sin nombre',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (platillo.descripcion != null &&
                                platillo.descripcion!.trim().isNotEmpty) ...[
                              Text(
                                platillo.descripcion!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Row(
                              children: [
                                if (platillo.categoria != null &&
                                    platillo.categoria!.trim().isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      platillo.categoria!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  platillo.disponible
                                      ? 'Disponible'
                                      : 'Agotado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: platillo.disponible
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(
                        '\$${platillo.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
