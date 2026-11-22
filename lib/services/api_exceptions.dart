/// Excepción lanzada cuando el backend responde `401` en un recurso
/// protegido, lo que indica que el token no es válido o ya expiró.
///
/// Es distinta de `AuthException`: un `401` al iniciar sesión es un error de
/// credenciales, mientras que este `401` invalida la sesión en curso.
class UnauthorizedException implements Exception {
  final String message;

  const UnauthorizedException([
    this.message = 'Sesión no autorizada o token inválido.',
  ]);

  @override
  String toString() => message;
}
