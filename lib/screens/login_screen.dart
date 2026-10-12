import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
      //Obtiene el tamaño de la pantalla
  final Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal:20),
          child: Column(
            children: [SizedBox(
              width: screenSize.width,
              height: 200,
              child: RiveAnimation.asset('assets/login-bear-animation.riv',
                ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}