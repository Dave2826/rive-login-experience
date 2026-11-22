import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/session_controller.dart';

class LoginScreen extends StatefulWidget {
  final SessionController session;

  const LoginScreen({super.key, required this.session});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

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
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Controladores de texto
  final usernameCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  // Errores de validación
  String? usernameError;
  String? passError;

  // Error general del inicio de sesión (conexión, timeout, servidor u otro).
  // Se muestra fuera de los campos para no atribuirlo al usuario.
  String? _authErrorMessage;

  // Estado de carga del botón (CircularProgressIndicator)
  bool _isLoading = false;

  // Guardia interna para impedir envíos duplicados, incluso después de
  // apagar el indicador de carga durante la animación de éxito.
  bool _isSubmitting = false;

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

    final username = usernameCtrl.text.trim();
    final pass = passCtrl.text;

    final usernameTypedError = username.isEmpty ? 'Ingresa tu usuario' : null;

    final passTypedError = pass.isEmpty ? 'Ingresa tu contraseña' : null;

    setState(() {
      usernameError = usernameTypedError;
      passError = passTypedError;
      _authErrorMessage = null;
    });

    FocusScope.of(context).unfocus();

    _typingDebounce?.cancel();

    if (usernameTypedError != null || passTypedError != null) {
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
      final authResponse = await _authService.login(
        LoginRequest(username: username, password: pass),
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

      // Guarda el token y deja que SessionGate muestre el catálogo.
      await widget.session.startSession(authResponse.token);
    } on AuthException catch (e) {
      await _applyAuthError(e.message, e.statusCode);
    } catch (_) {
      await _applyAuthError(
        'No se pudo conectar con el servidor. Revisa tu red e inténtalo de nuevo.',
        null,
      );
    }
  }

  // Restablece el estado y clasifica el error:
  // - 401: credenciales inválidas, se muestra bajo la contraseña.
  // - Conexión, timeout, servidor u otros: mensaje general, fuera de los campos.
  Future<void> _applyAuthError(String message, int? statusCode) async {
    if (!mounted) return;

    final isCredentialError = statusCode == 401;

    setState(() {
      _isLoading = false;
      _isSubmitting = false;

      usernameError = null;
      passError = isCredentialError ? message : null;
      _authErrorMessage = isCredentialError ? null : message;
    });

    // Igual que en el éxito, el trigger de fallo necesita la máquina en reposo.
    await _settleAnimation();

    if (!mounted) return;

    _trigFail?.fire();
  }

  @override
  void initState() {
    super.initState();

    // Aviso de sesión expirada o invalidada por 401; se consume una sola vez.
    _authErrorMessage = widget.session.consumeMessage();

    _usernameFocus.addListener(() {
      if (_usernameFocus.hasFocus) {
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

                // Campo de usuario
                TextField(
                  controller: usernameCtrl,
                  focusNode: _usernameFocus,
                  keyboardType: TextInputType.text,
                  onChanged: (value) {
                    if (_authErrorMessage != null) {
                      setState(() {
                        _authErrorMessage = null;
                      });
                    }

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
                    hintText: 'Usuario',
                    errorText: usernameError,
                    prefixIcon: const Icon(Icons.person),
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
                    if (_authErrorMessage != null) {
                      setState(() {
                        _authErrorMessage = null;
                      });
                    }

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

                // Error general del sistema (red, timeout, servidor u otro).
                if (_authErrorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _authErrorMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

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

    _usernameFocus.dispose();
    _passwordFocus.dispose();

    usernameCtrl.dispose();
    passCtrl.dispose();

    _typingDebounce?.cancel();

    super.dispose();
  }
}
