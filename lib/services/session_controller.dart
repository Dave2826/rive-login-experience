import 'package:flutter/foundation.dart';

import '../utils/jwt_utils.dart';
import 'token_storage.dart';

/// Estado de la sesión dentro de la aplicación.
enum SessionStatus {
  /// Se está leyendo el token guardado al arrancar.
  restoring,

  /// Hay un token vigente y se puede usar el catálogo.
  authenticated,

  /// No hay sesión válida: debe mostrarse el login.
  unauthenticated,
}

/// Única fuente de verdad de la sesión JWT.
///
/// Guarda el token en [TokenStorage], decide si un token persistido sigue
/// vigente y notifica cada transición para que la interfaz (SessionGate)
/// decida qué pantalla mostrar.
class SessionController extends ChangeNotifier {
  /// Aviso que se muestra en el login cuando la sesión deja de ser válida.
  static const String sessionExpiredMessage =
      'Tu sesión expiró o ya no es válida. Inicia sesión de nuevo.';

  final TokenStorage _storage;
  final DateTime Function() _now;

  SessionStatus _status = SessionStatus.restoring;
  String? _token;
  String? _message;
  bool _restored = false;

  SessionController(this._storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  SessionStatus get status => _status;

  String? get token => _token;

  /// Aviso pendiente para el login (expiración o `401`).
  String? get message => _message;

  bool get isAuthenticated => _status == SessionStatus.authenticated;

  /// Restaura la sesión guardada. Es idempotente: solo lee el almacén una vez.
  ///
  /// Un fallo de lectura, un token ausente, malformado o expirado deja la
  /// sesión cerrada (fail-closed). Si el token estaba guardado pero ya no es
  /// válido, se borra y se deja un aviso para el login.
  Future<void> restore() async {
    if (_restored) return;

    _restored = true;

    String? stored;

    try {
      stored = await _storage.read();
    } catch (_) {
      stored = null;
    }

    if (stored == null) {
      _message = null;
      _setStatus(SessionStatus.unauthenticated);
      return;
    }

    if (JwtUtils.isExpired(stored, now: _now())) {
      await _clearStorage();
      _message = sessionExpiredMessage;
      _setStatus(SessionStatus.unauthenticated);
      return;
    }

    _token = stored;
    _message = null;
    _setStatus(SessionStatus.authenticated);
  }

  /// Inicia la sesión con el token recién obtenido en el login.
  ///
  /// La sesión queda activa aunque el almacén falle: en ese caso solo se
  /// pierde la persistencia entre reinicios.
  Future<void> startSession(String token) async {
    _token = token;
    _message = null;
    _setStatus(SessionStatus.authenticated);

    try {
      await _storage.write(token);
    } catch (_) {
      // Sin persistencia la sesión sigue en memoria durante esta ejecución.
    }
  }

  /// Cierra la sesión por decisión del usuario.
  Future<void> signOut() async {
    _token = null;
    _message = null;

    await _clearStorage();

    _setStatus(SessionStatus.unauthenticated);
  }

  /// Invalida la sesión porque el backend la rechazó (`401`) o el token
  /// expiró. Es el único punto de cierre por invalidez.
  Future<void> expireSession({String message = sessionExpiredMessage}) async {
    _token = null;
    _message = message;

    await _clearStorage();

    _setStatus(SessionStatus.unauthenticated);
  }

  /// Devuelve el aviso pendiente y lo borra, para mostrarlo una sola vez.
  String? consumeMessage() {
    final message = _message;

    _message = null;

    return message;
  }

  Future<void> _clearStorage() async {
    try {
      await _storage.clear();
    } catch (_) {
      // Un fallo al borrar no debe impedir cerrar la sesión en memoria.
    }
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    notifyListeners();
  }
}
