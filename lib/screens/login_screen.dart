
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Control para mostrar / ocultar contraseña
  bool _isObscure = true;

  // 1.1 Máquina de estados / Cerebro de la animación
  StateMachineController? _controller;
  // StateMachineInput
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMITrigger? _numLook;

  @override
  Widget build(BuildContext context) {
    // Obtiene el tamaño de la pantalla
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: screenSize.width,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear-animation.riv',
                    stateMachines: ['Login Machine'],
                    // 1.2 Vincular la animación
                    onInit: (artboard) {
                      _controller =
                          StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );

                      // 1.3 Verificar que inició bien
                      if (_controller == null) return;

                      // Agregar el controlador al escenario
                      artboard.addController(_controller!);

                      // 1.4 Vincular las variables
                      _isChecking =
                          _controller!.findSMI('isCheching');
                      _isHandsUp =
                          _controller!.findSMI('isHandsUp');
                      _trigSuccess =
                          _controller!.findSMI('trigSuccess');
                      _trigFail =
                          _controller!.findSMI('triggFail');
                      _numLook =
                          _controller!.findSMI('numLook');
                    },
                  ),
                ),

                // Para separar elementos
                const SizedBox(height: 10),

                // Email
                TextField(
                  // 1.5 Vincular al campo de texto
                  onChanged: (value) {
                    if (_isHandsUp != null) {
                      // No tapes los ojos al ver el email
                      _isHandsUp!.change(false);
                    }

                    // Si isChecking es null
                    if (_isChecking == null) return;

                    // Activa el modo chismoso
                    _isChecking!.change(true);
                  },
                  decoration: InputDecoration(
                    hintText: "Email",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      // Para redondear los bordes
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Para separar elementos
                const SizedBox(height: 10),

                // Contraseña
                TextField(
                  // 1.5.1 Vincular al campo de texto
                  onChanged: (value) {
                    if (_isChecking != null) {
                      // No actives el modo chismoso en contraseña
                      _isChecking!.change(false);
                    }

                    // Si handsUp no es null
                    if (_isHandsUp == null) return;

                    // Tapa lo ojos
                    _isHandsUp!.change(true);
                  },
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      onPressed: () {
                        // Refrescar el icono
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                      icon: Icon(
                        // If temario
                        _isObscure
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                    border: OutlineInputBorder(
                      // Para redondear los bordes
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
