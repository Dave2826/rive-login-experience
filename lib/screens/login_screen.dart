
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import 'products_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;

  StateMachineController? _controller;

  // State Machine Inputs
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  // Timer para controlar el recorrido de la mirada
  Timer? _typingDebounce;

  // FocusNodes
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Controladores de texto
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  // Errores de validación
  String? emailError;
  String? passError;

  // Estado de carga para impedir envíos repetidos
  bool _isLoading = false;

  // Validador de correo
  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  // Validador de contraseña
  bool isValidPassword(String pass) {
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );
    return re.hasMatch(pass);
  }

  // Acción del botón Login
  Future<void> _onLogin() async {
    if (_isLoading) return;

    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;

    final emailTypedError =
        isValidEmail(email) ? null : 'Correo electrónico inválido';

    final passTypedError =
        isValidPassword(pass) ? null : 'Contraseña inválida';

    setState(() {
      emailError = emailTypedError;
      passError = passTypedError;
    });

    FocusScope.of(context).unfocus();

    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    if (emailTypedError != null || passTypedError != null) {
      _trigFail?.fire();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;

      _trigSuccess?.fire();

      // Mantener la carga mientras se reproduce la animación de éxito.
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductsScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        passError = _authErrorMessage(e.code);
      });

      _trigFail?.fire();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        passError = 'No se pudo iniciar sesión. Inténtalo de nuevo';
      });

      _trigFail?.fire();
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo';
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu red e inténtalo de nuevo';
      case 'operation-not-allowed':
        return 'El inicio de sesión con correo no está habilitado';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos';
      default:
        return 'No se pudo iniciar sesión. Inténtalo de nuevo';
    }
  }

  @override
  void initState() {
    super.initState();

    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        _isHandsUp?.change(false);
        _numLook?.value = 50.0;
      }
    });

    _passwordFocus.addListener(() {
      _isHandsUp?.change(_passwordFocus.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Animación Rive
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear-animation.riv',
                    stateMachines: const ['Login Machine'],
                    onInit: (artboard) {
                      _controller =
                          StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );

                      if (_controller == null) return;

                      artboard.addController(_controller!);

                      _isChecking =
                          _controller!.findSMI('isChecking');
                      _isHandsUp =
                          _controller!.findSMI('isHandsUp');
                      _trigSuccess =
                          _controller!.findSMI('trigSuccess');
                      _trigFail =
                          _controller!.findSMI('trigFail');
                      _numLook =
                          _controller!.findSMI('numLook');
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Campo de correo
                TextField(
                  controller: emailCtrl,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    _isHandsUp?.change(false);

                    if (_isChecking == null) return;

                    _isChecking!.change(true);

                    final look = (value.length / 80.0 * 100.0)
                        .clamp(0.0, 100.0);

                    _numLook?.value = look;

                    _typingDebounce?.cancel();

                    _typingDebounce =
                        Timer(const Duration(seconds: 3), () {
                      if (!mounted) return;
                      _isChecking?.change(false);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Email',
                    errorText: emailError,
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Campo de contraseña
                TextField(
                  controller: passCtrl,
                  focusNode: _passwordFocus,
                  obscureText: _isObscure,
                  onChanged: (value) {
                    _isHandsUp?.change(true);
                  },
                  decoration: InputDecoration(
                    hintText: 'Password',
                    errorText: passError,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Recuperar contraseña
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Botón Login
                SizedBox(
                  width: size.width,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Don\'t have an account? '),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();

    emailCtrl.dispose();
    passCtrl.dispose();

    _typingDebounce?.cancel();

    super.dispose();
  }
}
