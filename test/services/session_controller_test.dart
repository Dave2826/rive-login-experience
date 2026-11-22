import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:login_drive_animation/services/session_controller.dart';
import 'package:login_drive_animation/services/token_storage.dart';

/// Doble en memoria de [TokenStorage]; nunca toca canales nativos.
class _FakeTokenStorage implements TokenStorage {
  String? stored;
  Object? readError;
  Object? writeError;
  Object? clearError;

  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  _FakeTokenStorage({this.stored, this.readError, this.writeError});

  @override
  Future<String?> read() async {
    readCount++;

    if (readError != null) throw readError!;

    return stored;
  }

  @override
  Future<void> write(String token) async {
    writeCount++;

    if (writeError != null) throw writeError!;

    stored = token;
  }

  @override
  Future<void> clear() async {
    clearCount++;

    if (clearError != null) throw clearError!;

    stored = null;
  }
}

/// Construye un token con la forma `cabecera.payload.firma`.
String _tokenWithClaims(Map<String, dynamic> claims) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(claims)));

  return '$header.$body.firma-de-prueba';
}

String _tokenExpiringAt(DateTime moment) {
  return _tokenWithClaims(<String, dynamic>{
    'sub': 'admin',
    'exp': moment.millisecondsSinceEpoch ~/ 1000,
  });
}

void main() {
  final DateTime now = DateTime.utc(2026, 11, 21, 12);

  SessionController controllerFor(
    _FakeTokenStorage storage, {
    DateTime? clock,
  }) {
    return SessionController(storage, now: () => clock ?? now);
  }

  group('SessionController · estado inicial', () {
    test('empieza en restoring sin token ni aviso', () {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      expect(session.status, SessionStatus.restoring);
      expect(session.token, isNull);
      expect(session.message, isNull);
      expect(session.isAuthenticated, isFalse);
      expect(storage.readCount, 0);
    });
  });

  group('SessionController.restore', () {
    test('sin token guardado deja la sesión cerrada sin aviso', () async {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.token, isNull);
      expect(session.message, isNull);
      expect(storage.readCount, 1);
      expect(storage.clearCount, 0);
    });

    test('con token vigente autentica y expone el token', () async {
      final token = _tokenExpiringAt(now.add(const Duration(hours: 1)));
      final storage = _FakeTokenStorage(stored: token);
      final session = controllerFor(storage);

      await session.restore();

      expect(session.status, SessionStatus.authenticated);
      expect(session.isAuthenticated, isTrue);
      expect(session.token, token);
      expect(session.message, isNull);
      expect(storage.stored, token);
    });

    test('con token expirado borra el almacén y avisa', () async {
      final token = _tokenExpiringAt(now.subtract(const Duration(minutes: 1)));
      final storage = _FakeTokenStorage(stored: token);
      final session = controllerFor(storage);

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.token, isNull);
      expect(session.message, SessionController.sessionExpiredMessage);
      expect(storage.clearCount, 1);
      expect(storage.stored, isNull);
    });

    test('con token malformado borra el almacén y avisa', () async {
      final storage = _FakeTokenStorage(stored: 'esto-no-es-un-jwt');
      final session = controllerFor(storage);

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.token, isNull);
      expect(session.message, SessionController.sessionExpiredMessage);
      expect(storage.stored, isNull);
    });

    test('con token sin exp lo trata como expirado', () async {
      final token = _tokenWithClaims(<String, dynamic>{'sub': 'admin'});
      final storage = _FakeTokenStorage(stored: token);
      final session = controllerFor(storage);

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.message, SessionController.sessionExpiredMessage);
      expect(storage.stored, isNull);
    });

    test('un fallo de lectura cierra la sesión sin lanzar', () async {
      final storage = _FakeTokenStorage(
        stored: _tokenExpiringAt(now.add(const Duration(hours: 1))),
        readError: const FileSystemException('almacén no disponible'),
      );
      final session = controllerFor(storage);

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.token, isNull);
      expect(session.message, isNull);
    });

    test('es idempotente y notifica una sola transición', () async {
      final storage = _FakeTokenStorage(
        stored: _tokenExpiringAt(now.add(const Duration(hours: 1))),
      );
      final session = controllerFor(storage);

      var notifications = 0;
      session.addListener(() => notifications++);

      await session.restore();
      await session.restore();

      expect(storage.readCount, 1);
      expect(notifications, 1);
      expect(session.status, SessionStatus.authenticated);
    });
  });

  group('SessionController.startSession', () {
    test('persiste el token y autentica', () async {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      await session.startSession('jwt-nuevo');

      expect(session.status, SessionStatus.authenticated);
      expect(session.token, 'jwt-nuevo');
      expect(session.message, isNull);
      expect(storage.writeCount, 1);
      expect(storage.stored, 'jwt-nuevo');
    });

    test('si el almacén falla mantiene la sesión en memoria', () async {
      final storage = _FakeTokenStorage(
        writeError: const FileSystemException('sin espacio'),
      );
      final session = controllerFor(storage);

      await session.startSession('jwt-nuevo');

      expect(session.status, SessionStatus.authenticated);
      expect(session.token, 'jwt-nuevo');
      expect(storage.stored, isNull);
    });

    test('limpia un aviso previo de expiración', () async {
      final expired = _tokenExpiringAt(now.subtract(const Duration(hours: 1)));
      final storage = _FakeTokenStorage(stored: expired);
      final session = controllerFor(storage);

      await session.restore();
      expect(session.message, isNotNull);

      await session.startSession('jwt-nuevo');

      expect(session.message, isNull);
      expect(session.status, SessionStatus.authenticated);
    });
  });

  group('SessionController.signOut', () {
    test('borra el token y cierra la sesión sin aviso', () async {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      await session.startSession('jwt-nuevo');
      await session.signOut();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.token, isNull);
      expect(session.message, isNull);
      expect(storage.clearCount, 1);
      expect(storage.stored, isNull);
    });

    test('un fallo al borrar no impide cerrar la sesión', () async {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      await session.startSession('jwt-nuevo');

      storage.clearError = const FileSystemException('almacén ocupado');

      await session.signOut();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.token, isNull);
    });
  });

  group('SessionController.expireSession', () {
    test('invalida la sesión, borra el token y deja un aviso', () async {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      await session.startSession('jwt-nuevo');
      await session.expireSession();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.token, isNull);
      expect(storage.stored, isNull);

      expect(session.message, SessionController.sessionExpiredMessage);
      expect(session.consumeMessage(), SessionController.sessionExpiredMessage);
      expect(session.consumeMessage(), isNull);
    });

    test('acepta un aviso personalizado', () async {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      await session.startSession('jwt-nuevo');
      await session.expireSession(message: 'Sesión rechazada por el servidor.');

      expect(session.consumeMessage(), 'Sesión rechazada por el servidor.');
    });
  });

  group('SessionController · notificaciones', () {
    test('notifica en cada transición', () async {
      final storage = _FakeTokenStorage();
      final session = controllerFor(storage);

      var notifications = 0;
      session.addListener(() => notifications++);

      await session.restore();
      await session.startSession('jwt-nuevo');
      await session.signOut();

      expect(notifications, 3);
    });
  });
}
