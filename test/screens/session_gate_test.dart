import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:login_drive_animation/screens/login_screen.dart';
import 'package:login_drive_animation/screens/products_screen.dart';
import 'package:login_drive_animation/screens/session_gate.dart';
import 'package:login_drive_animation/services/product_service.dart';
import 'package:login_drive_animation/services/session_controller.dart';

import '../helpers/test_doubles.dart';

Future<void> _pumpGate(
  WidgetTester tester,
  SessionController session, {
  ProductService? productService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SessionGate(
        session: session,
        productService: productService,
        loginAnimation: const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pump();
}

/// Avanza unos frames sin `pumpAndSettle`: Rive anima de forma continua.
Future<void> _pumpFrames(WidgetTester tester, [int count = 3]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('muestra el indicador mientras restaura la sesión', (
    tester,
  ) async {
    final pending = Completer<String?>();
    final storage = FakeTokenStorage(pendingRead: pending);
    final session = SessionController(storage);

    await _pumpGate(tester, session);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(null);
    await _pumpFrames(tester, 2);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('sin token muestra el login', (tester) async {
    final session = SessionController(FakeTokenStorage());

    await _pumpGate(tester, session);
    await _pumpFrames(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Usuario o correo'), findsOneWidget);
  });

  testWidgets('con token vigente muestra el catálogo', (tester) async {
    final storage = FakeTokenStorage(
      stored: jwtExpiringAt(DateTime.now().add(const Duration(hours: 1))),
    );
    final session = SessionController(storage);
    final productService = ProductService(
      client: MockClient((_) async => jsonResponse(<Object?>[])),
    );

    await _pumpGate(tester, session, productService: productService);
    await _pumpFrames(tester);

    expect(find.byType(ProductsScreen), findsOneWidget);
    expect(find.text('Menú de platillos'), findsOneWidget);

    await _pumpFrames(tester, 2);

    expect(find.text('No hay platillos disponibles'), findsOneWidget);
  });

  testWidgets('con token expirado muestra el login y avisa', (tester) async {
    final storage = FakeTokenStorage(
      stored: jwtExpiringAt(DateTime.now().subtract(const Duration(hours: 1))),
    );
    final session = SessionController(storage);

    await _pumpGate(tester, session);
    await _pumpFrames(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text(SessionController.sessionExpiredMessage),
      findsOneWidget,
    );
    expect(storage.stored, isNull);
  });
}
