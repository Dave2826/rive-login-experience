import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login_drive_animation/screens/products_screen.dart';
import 'package:login_drive_animation/services/product_service.dart';
import 'package:login_drive_animation/services/session_controller.dart';

import '../helpers/test_doubles.dart';

const List<Map<String, Object?>> _platillosJson = <Map<String, Object?>>[
  <String, Object?>{
    'id': 1,
    'nombre': 'Hamburguesa Clásica',
    'descripcion': 'Carne de res con queso.',
    'precio': 180.0,
    'categoria': 'Hamburguesas',
    'disponible': true,
  },
  <String, Object?>{
    'id': 2,
    'nombre': 'Agua de horchata',
    'descripcion': null,
    'precio': 35,
    'categoria': null,
    'disponible': false,
  },
];

Future<SessionController> _authenticatedSession() async {
  final session = SessionController(FakeTokenStorage());

  await session.startSession(
    jwtExpiringAt(DateTime.now().add(const Duration(hours: 1))),
  );

  return session;
}

ProductService _serviceWith(MockClient client) =>
    ProductService(client: client);

Future<void> _pumpProducts(
  WidgetTester tester, {
  required SessionController session,
  required ProductService productService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProductsScreen(session: session, productService: productService),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('muestra el estado de carga', (tester) async {
    final pending = Completer<http.Response>();

    await _pumpProducts(
      tester,
      session: await _authenticatedSession(),
      productService: _serviceWith(MockClient((_) => pending.future)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(jsonResponse(<Object?>[]));
    await tester.pump();
    await tester.pump();

    expect(find.text('No hay platillos disponibles'), findsOneWidget);
  });

  testWidgets('muestra el estado vacío', (tester) async {
    await _pumpProducts(
      tester,
      session: await _authenticatedSession(),
      productService: _serviceWith(
        MockClient((_) async => jsonResponse(<Object?>[])),
      ),
    );
    await tester.pump();

    expect(find.text('No hay platillos disponibles'), findsOneWidget);
  });

  testWidgets('muestra el estado de error y permite reintentar', (
    tester,
  ) async {
    await _pumpProducts(
      tester,
      session: await _authenticatedSession(),
      productService: _serviceWith(
        MockClient(
          (_) async => jsonResponse(<String, String>{'error': 'boom'}, status: 500),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Error interno del servidor al cargar el menú.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ElevatedButton, 'Reintentar'),
      findsOneWidget,
    );
  });

  testWidgets('renderiza los productos simulados', (tester) async {
    await _pumpProducts(
      tester,
      session: await _authenticatedSession(),
      productService: _serviceWith(
        MockClient((_) async => jsonResponse(_platillosJson)),
      ),
    );
    await tester.pump();

    expect(find.text('Hamburguesa Clásica'), findsOneWidget);
    expect(find.text('Hamburguesas'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Agua de horchata'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text(r'$180.00'), findsOneWidget);
    expect(find.text(r'$35.00'), findsOneWidget);
  });

  testWidgets('cancelar el cierre de sesión no altera la sesión', (
    tester,
  ) async {
    final session = await _authenticatedSession();

    await _pumpProducts(
      tester,
      session: session,
      productService: _serviceWith(
        MockClient((_) async => jsonResponse(<Object?>[])),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres cerrar la sesión actual?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(session.status, SessionStatus.authenticated);
    expect(find.byType(ProductsScreen), findsOneWidget);
  });
}
