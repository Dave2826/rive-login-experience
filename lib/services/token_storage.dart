import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Contrato de almacenamiento del token JWT.
///
/// Abstrae el mecanismo concreto para poder sustituirlo por un doble en las
/// pruebas sin depender de canales nativos.
abstract class TokenStorage {
  /// Devuelve el token guardado o `null` si no existe o está vacío.
  Future<String?> read();

  /// Guarda el token, reemplazando cualquier valor anterior.
  Future<void> write(String token);

  /// Elimina el token del almacenamiento.
  Future<void> clear();
}

/// Implementación segura basada en `flutter_secure_storage`.
///
/// En Android usa el Keystore del sistema (RSA-OAEP + AES-GCM), en iOS y
/// macOS el Keychain y en escritorio el almacén de credenciales del sistema.
/// El token nunca se guarda en texto plano.
class SecureTokenStorage implements TokenStorage {
  /// Clave única del token dentro del almacén.
  static const String tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    final value = await _storage.read(key: tokenKey);

    if (value == null) return null;

    final token = value.trim();

    return token.isEmpty ? null : token;
  }

  @override
  Future<void> write(String token) {
    return _storage.write(key: tokenKey, value: token);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: tokenKey);
  }
}
