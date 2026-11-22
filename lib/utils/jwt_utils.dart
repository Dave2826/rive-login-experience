import 'dart:convert';

/// Utilidades de lectura de un JWT, sin verificar la firma.
///
/// Solo sirve para decidir si conviene restaurar una sesión guardada. El
/// servidor sigue siendo la autoridad: un token manipulado se detecta con la
/// respuesta `401` del backend.
///
/// Criterio fail-closed: cualquier token malformado, sin `exp` legible o
/// caducado se considera expirado.
class JwtUtils {
  JwtUtils._();

  /// Devuelve el payload (claims) del token o `null` si no se puede leer.
  ///
  /// Un JWT válido en forma tiene tres segmentos separados por puntos:
  /// cabecera, payload y firma.
  static Map<String, dynamic>? payload(String? token) {
    if (token == null) return null;

    final parts = token.split('.');

    if (parts.length != 3) return null;

    try {
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(decoded);

      if (json is! Map<String, dynamic>) return null;

      return json;
    } catch (_) {
      return null;
    }
  }

  /// Devuelve la fecha de expiración (`exp`) en UTC o `null` si no existe.
  static DateTime? expiry(String? token) {
    final exp = payload(token)?['exp'];

    if (exp is! num || !exp.isFinite) return null;

    return DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).round(),
      isUtc: true,
    );
  }

  /// Indica si el token debe considerarse expirado.
  ///
  /// Devuelve `true` cuando el token es nulo, está malformado, no incluye un
  /// `exp` numérico o la fecha ya pasó. La comparación es inclusiva: en el
  /// instante exacto de expiración el token ya no es válido.
  static bool isExpired(String? token, {DateTime? now}) {
    final exp = expiry(token);

    if (exp == null) return true;

    final reference = (now ?? DateTime.now()).toUtc();

    return !exp.isAfter(reference);
  }
}
