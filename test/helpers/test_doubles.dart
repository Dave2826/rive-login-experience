import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:login_drive_animation/services/token_storage.dart';

/// Doble en memoria de [TokenStorage]; nunca toca canales nativos.
///
/// Si [pendingRead] está definido, [read] devuelve su futuro pendiente, lo
/// que permite observar el estado `restoring` de la interfaz.
class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.stored, this.pendingRead});

  String? stored;
  Completer<String?>? pendingRead;

  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<String?> read() {
    readCount++;

    final pending = pendingRead;

    if (pending != null) return pending.future;

    return Future<String?>.value(stored);
  }

  @override
  Future<void> write(String token) async {
    writeCount++;
    stored = token;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    stored = null;
  }
}

/// Construye un JWT de prueba (la firma no se verifica) que expira en [moment].
String jwtExpiringAt(DateTime moment, {String subject = 'admin'}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final body = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'sub': subject,
        'exp': moment.millisecondsSinceEpoch ~/ 1000,
      }),
    ),
  );

  return '$header.$body.firma-de-prueba';
}

/// Respuesta HTTP JSON para los clientes simulados.
http.Response jsonResponse(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
