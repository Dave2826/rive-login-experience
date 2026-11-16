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

  // Estado de carga del botón (CircularProgressIndicator)
  bool _isLoading = false;

  // Guardia interna para impedir envíos duplicados, incluso después de
  // apagar el indicador de carga durante la animación de éxito.
  bool _isSubmitting = false;

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

  // Devuelve el oso a reposo y espera a que la State Machine termine sus
  // transiciones. Los triggers de Rive duran un solo frame (`advanceInputs`
  // los reinicia), así que dispararlos durante una transición hace que se
  // pierdan.
  Future<void> _settleAnimation() async {
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    await Future.delayed(const Duration(milliseconds: 700));
  }

  // Acción del botón Login
  Future<void> _onLogin() async {
    if (_isSubmitting) return;

    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;

    final emailTypedError = isValidEmail(email)
        ? null
        : 'Correo electrónico inválido';

    final passTypedError = isValidPassword(pass) ? null : 'Contraseña inválida';

    setState(() {
      emailError = emailTypedError;
      passError = passTypedError;
    });

    FocusScope.of(context).unfocus();

    _typingDebounce?.cancel();

    if (emailTypedError != null || passTypedError != null) {
      // Esperar a que la máquina vuelva a reposo antes de disparar el trigger.
      await _settleAnimation();

      if (!mounted) return;

      _trigFail?.fire();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;

      // Apagar el indicador de carga y celebrar con el osito. El guardia
      // `_isSubmitting` sigue activo para bloquear envíos duplicados.
      setState(() {
        _isLoading = false;
      });

      // Dejar que la State Machine regrese a reposo antes de disparar el
      // trigger de éxito, que de lo contrario se perdería.
      await _settleAnimation();

      if (!mounted) return;

      _trigSuccess?.fire();

      // Permitir que la animación de éxito se reproduzca antes de navegar.
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductsScreen()),
      );
    } on FirebaseAuthException catch (e) {
      await _applyAuthError(e.code);
    } catch (_) {
      await _applyAuthError(null);
    }
  }

  // Restablece el estado y muestra el error en el campo que corresponda.
  Future<void> _applyAuthError(String? code) async {
    final message = _authErrorMessage(code);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isSubmitting = false;

      if (code == 'user-not-found' || code == 'invalid-email') {
        emailError = message;
        passError = null;
      } else {
        passError = message;
        emailError = null;
      }
    });

    // Igual que en el éxito, el trigger de fallo necesita la máquina en reposo.
    await _settleAnimation();

    if (!mounted) return;

    _trigFail?.fire();
  }

  String _authErrorMessage(String? code) {
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
                    // Un solo controlador: el de `onInit`. Añadir también
                    // `stateMachines:` crearía un segundo controlador de la
                    // misma State Machine y avanzaría todo dos veces por frame.
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );

                      if (_controller == null) return;

                      artboard.addController(_controller!);

                      _isChecking = _controller!.findSMI('isChecking');
                      _isHandsUp = _controller!.findSMI('isHandsUp');
                      _trigSuccess = _controller!.findSMI('trigSuccess');
                      _trigFail = _controller!.findSMI('trigFail');
                      _numLook = _controller!.findSMI('numLook');
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

                    final look = (value.length / 80.0 * 100.0).clamp(
                      0.0,
                      100.0,
                    );

                    _numLook?.value = look;

                    _typingDebounce?.cancel();

                    _typingDebounce = Timer(const Duration(seconds: 3), () {
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
                        _isObscure ? Icons.visibility : Icons.visibility_off,
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
                      style: TextStyle(decoration: TextDecoration.underline),
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
                        : const Text('Login', style: TextStyle(fontSize: 18)),
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
    _controller?.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();

    emailCtrl.dispose();
    passCtrl.dispose();

    _typingDebounce?.cancel();

    super.dispose();
  }
}
