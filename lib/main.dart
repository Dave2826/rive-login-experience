import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/session_gate.dart';
import 'services/session_controller.dart';
import 'services/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(MyApp(session: SessionController(SecureTokenStorage())));
}

class MyApp extends StatelessWidget {
  final SessionController session;

  const MyApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SessionGate(session: session),
    );
  }
}
