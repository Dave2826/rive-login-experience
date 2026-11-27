import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login_drive_animation/screens/login_screen.dart';
import 'package:login_drive_animation/services/auth_service.dart';
import 'package:login_drive_animation/services/session_controller.dart';

import '../helpers/test_doubles.dart';

SessionController _session() => SessionController(FakeTokenStorage());

AuthService _authService(MockClient client) => AuthService(client: client);

Future<void> _pumpLogin(
  WidgetTester tester, {
  required SessionController session,
  required AuthService authService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(
        session: session,
        authService: authService,
        animation: const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pump();
}

/// Avanza el reloj lo suficiente para drenar `_settleAnimation` (700 ms) y
/// el debounce de escritura del usuario (3 s).
Future<void> _drainLoginTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('muestra campos, botón y traducciones locales', (tester) async {
    final client = MockClient(
      (_) async => jsonResponse(<String, String>{'token': 'jwt'}),
    );

    await _pumpLogin(
      tester,
      session: _session(),
      authService: _authService(client),
    );

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('tu@correo.com'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Iniciar sesión'), findsOneWidget);
    expect(find.text('¿No tienes una cuenta? '), findsOneWidget);
    expect(find.text('Regístra'), findsOneWidget);
  });

  testWidgets('muestra el aviso de sesión pendiente', (tester) async {
    final session = _session();

    await session.startSession(
      jwtExpiringAt(DateTime.now().add(const Duration(hours: 1))),
    );
    await session.expireSession(
      message: 'Sesión rechazada por el servidor.',
    );

    await _pumpLogin(
      tester,
      session: session,
      authService: _authService(
        MockClient((_) async => jsonResponse(<String, String>{'token': 'x'})),
      ),
    );

    expect(find.text('Sesión rechazada por el servidor.'), findsOneWidget);
    expect(session.consumeMessage(), isNull);
  });

  testWidgets('muestra el indicador de carga y deshabilita el botón', (
    tester,
  ) async {
    final pending = Completer<http.Response>();

    await _pumpLogin(
      tester,
      session: _session(),
      authService: _authService(MockClient((_) => pending.future)),
    );

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    pending.complete(jsonResponse(<String, String>{'error': 'no'}, status: 401));
    await tester.pump();
    await tester.pump();
    await _drainLoginTimers(tester);
  });

  testWidgets('muestra credenciales inválidas con 401', (tester) async {
    final client = MockClient(
      (_) async => jsonResponse(<String, String>{'error': 'no'}, status: 401),
    );

    await _pumpLogin(
      tester,
      session: _session(),
      authService: _authService(client),
    );

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Credenciales inválidas'), findsOneWidget);

    await _drainLoginTimers(tester);
  });
}