class Platillo {
  final int id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? categoria;
  final bool disponible;

  const Platillo({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    this.categoria,
    required this.disponible,
  });

  factory Platillo.fromJson(Map<String, dynamic> json) {
    return Platillo(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      categoria: json['categoria'] as String?,
      disponible: json['disponible'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'precio': precio,
      if (categoria != null) 'categoria': categoria,
      'disponible': disponible,
    };
  }
}
