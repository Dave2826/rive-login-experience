import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:login_drive_animation/utils/jwt_utils.dart';

/// Construye un token con la forma `cabecera.payload.firma`.
///
/// La firma no se verifica, así que basta con una cadena cualquiera.
String _tokenWithPayload(Object? payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));

  return '$header.$body.firma-de-prueba';
}

/// Token con `exp` calculado a partir de [now] más [seconds] segundos.
String _tokenExpiringIn(DateTime now, int seconds) {
  return _tokenWithPayload(<String, dynamic>{
    'sub': 'admin',
    'exp': now.millisecondsSinceEpoch ~/ 1000 + seconds,
  });
}

void main() {
  final DateTime now = DateTime.utc(2026, 11, 21, 12);

  group('JwtUtils.payload', () {
    test('devuelve los claims de un token bien formado', () {
      final token = _tokenWithPayload(<String, dynamic>{
        'sub': 'admin',
        'exp': 1764000000,
      });

      final claims = JwtUtils.payload(token);

      expect(claims, isNotNull);
      expect(claims!['sub'], 'admin');
      expect(claims['exp'], 1764000000);
    });

    test('devuelve null con un token nulo o vacío', () {
      expect(JwtUtils.payload(null), isNull);
      expect(JwtUtils.payload(''), isNull);
    });

    test('devuelve null cuando no tiene tres segmentos', () {
      expect(JwtUtils.payload('cabecera.payload'), isNull);
      expect(JwtUtils.payload('un-solo-segmento'), isNull);
    });

    test('devuelve null cuando el payload no es JSON', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final body = base64Url.encode(utf8.encode('esto-no-es-json'));

      expect(JwtUtils.payload('$header.$body.firma'), isNull);
    });
  });

  group('JwtUtils.expiry', () {
    test('devuelve la fecha de expiración en UTC', () {
      final token = _tokenWithPayload(<String, dynamic>{'exp': 1764000000});

      final exp = JwtUtils.expiry(token);

      expect(exp, isNotNull);
      expect(exp!.isUtc, isTrue);
      expect(
        exp,
        DateTime.fromMillisecondsSinceEpoch(1764000000 * 1000, isUtc: true),
      );
    });

    test('devuelve null cuando exp no es numérico o no existe', () {
      expect(
        JwtUtils.expiry(
          _tokenWithPayload(<String, dynamic>{'exp': '1764000000'}),
        ),
        isNull,
      );
      expect(
        JwtUtils.expiry(_tokenWithPayload(<String, dynamic>{'sub': 'admin'})),
        isNull,
      );
    });
  });

  group('JwtUtils.isExpired', () {
    test('un token con exp futuro no está expirado', () {
      final token = _tokenExpiringIn(now, 3600);

      expect(JwtUtils.isExpired(token, now: now), isFalse);
    });

    test('un token con exp pasado está expirado', () {
      final token = _tokenExpiringIn(now, -3600);

      expect(JwtUtils.isExpired(token, now: now), isTrue);
    });

    test('el instante exacto de expiración cuenta como expirado', () {
      final token = _tokenExpiringIn(now, 0);

      expect(JwtUtils.isExpired(token, now: now), isTrue);
    });

    test('un token sin exp se considera expirado', () {
      final token = _tokenWithPayload(<String, dynamic>{'sub': 'admin'});

      expect(JwtUtils.isExpired(token, now: now), isTrue);
    });

    test('un exp no numérico se considera expirado', () {
      final token = _tokenWithPayload(<String, dynamic>{'exp': 'mañana'});

      expect(JwtUtils.isExpired(token, now: now), isTrue);
    });

    test('un token con dos segmentos se considera expirado', () {
      expect(JwtUtils.isExpired('cabecera.payload', now: now), isTrue);
    });

    test('un payload con base64 inválido se considera expirado', () {
      expect(JwtUtils.isExpired('cabecera.%%%%.firma', now: now), isTrue);
    });

    test('un payload que no es JSON se considera expirado', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final body = base64Url.encode(utf8.encode('no-es-un-payload'));

      expect(JwtUtils.isExpired('$header.$body.firma', now: now), isTrue);
    });

    test('un token nulo o vacío se considera expirado', () {
      expect(JwtUtils.isExpired(null, now: now), isTrue);
      expect(JwtUtils.isExpired('', now: now), isTrue);
    });
  });
}
