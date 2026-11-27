import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_drive_animation/screens/sign_up_screen.dart';

Future<void> _pumpSignUp(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));
  await tester.pump();
}

void main() {
  testWidgets('muestra los campos requeridos y el botón de registro', (
    tester,
  ) async {
    await _pumpSignUp(tester);

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Correo institucional'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Confirmar contraseña'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Crear cuenta'),
      findsOneWidget,
    );
  });

  testWidgets('valida los campos vacíos sin llamar a Firebase', (tester) async {
    await _pumpSignUp(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('El correo es obligatorio'), findsOneWidget);
    expect(find.text('La contraseña es obligatoria'), findsOneWidget);
    expect(find.text('Confirma tu contraseña'), findsOneWidget);
  });

  testWidgets('rechaza un dominio no institucional antes de Firebase', (
    tester,
  ) async {
    await _pumpSignUp(tester);

    await tester.enterText(find.byType(TextField).at(0), 'user@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'Abc1234@');
    await tester.enterText(find.byType(TextField).at(2), 'Abc1234@');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pump();

    expect(
      find.text('Usa tu correo institucional (@tecdesoftware.edu.mx)'),
      findsOneWidget,
    );
    expect(find.text('Este correo ya está registrado'), findsNothing);
  });
}
