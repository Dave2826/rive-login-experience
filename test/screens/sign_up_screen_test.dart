import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_drive_animation/config/app_strings.dart';

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
    expect(find.text(AppStrings.institutionalEmailLabel), findsOneWidget);
    expect(find.text(AppStrings.passwordLabel), findsOneWidget);
    expect(find.text(AppStrings.confirmPasswordLabel), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, AppStrings.signUpButton), findsOneWidget);
  });

  testWidgets('valida los campos vacíos sin llamar a Firebase', (tester) async {
    await _pumpSignUp(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.signUpButton));
    await tester.pump();

    expect(find.text(AppStrings.emailRequired), findsOneWidget);
    expect(find.text(AppStrings.passwordRequired), findsOneWidget);
    expect(find.text(AppStrings.confirmRequired), findsOneWidget);
  });

  testWidgets('rechaza un dominio no institucional antes de Firebase', (
    tester,
  ) async {
    await _pumpSignUp(tester);

    await tester.enterText(find.byType(TextField).at(0), 'user@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'Abc1234@');
    await tester.enterText(find.byType(TextField).at(2), 'Abc1234@');

    await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.signUpButton));
    await tester.pump();

    expect(find.text(AppStrings.nonInstitutionalDomain), findsOneWidget);
    expect(find.text(AppStrings.emailAlreadyRegistered), findsNothing);
  });
}