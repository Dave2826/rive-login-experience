import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/session_controller.dart';
import 'sign_up_screen.dart';

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

  // Mensaje genérico de error del login (OWASP: no revelar qué falló).
  static const String _loginErrorMessage = 'Credenciales inválidas';

  // Fallo ajeno a las credenciales (red, timeout, servidor o respuesta no
  // interpretable). No revela si el usuario existe, pero tampoco disfraza un
  // problema de infraestructura como credenciales incorrectas.
  static const String _connectionErrorMessage =
      'No se pudo iniciar sesión en este momento. '
      'Verifica tu conexión e inténtalo de nuevo.';

  // Único estado de error del login. Campos vacíos y credenciales incorrectas
  // muestran el mensaje genérico; los fallos de red, timeout o servidor usan el
  // mensaje de conexión. En ambos casos se pinta en un solo componente fuera de
  // los campos.
  String? _loginError;

  // Estado de carga del botón (CircularProgressIndicator)
  bool _isLoading = false;

  // Guardia interna para impedir envíos duplicados, incluso después de
  // apagar el indicador de carga durante la animación de éxito.
  bool _isSubmitting = false;

  // La transición `Hands up → Hands down → Idle` del asset encadena una
  // animación y una mezcla cercanas a 1 s. Con 700 ms la máquina todavía no
  // estaba en `Idle`, así que el trigger se descartaba y el oso terminaba
  // sonriendo. Cuando las manos estaban arriba se espera lo suficiente para
  // que vuelva a reposo antes de disparar el trigger.
  static const Duration _settleWhenHandsUp = Duration(milliseconds: 1800);
  static const Duration _settleWhenIdle = Duration(milliseconds: 700);

  // Devuelve el oso a reposo y espera a que la State Machine termine sus
  // transiciones. Los triggers de Rive duran un solo frame (`advanceInputs`
  // los reinicia), así que dispararlos durante una transición hace que se
  // pierdan.
  Future<void> _settleAnimation({required bool handsWereUp}) async {
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    await Future.delayed(handsWereUp ? _settleWhenHandsUp : _settleWhenIdle);
  }

  // Acción del botón Login
  Future<void> _onLogin() async {
    if (_isSubmitting) return;

    final username = usernameCtrl.text.trim();
    final pass = passCtrl.text;

    // Se mantiene la comprobación de campos vacíos, pero sin mensajes que
    // distingan qué campo falta: un único error genérico.
    final hasEmptyField = username.isEmpty || pass.isEmpty;

    // Las manos del oso solo bajan con `unfocus()`. Si estaban arriba, la
    // State Machine encadena `Hands down` antes de volver a `Idle` y hay que
    // esperar más antes de disparar un trigger.
    final handsWereUp = _isHandsUp?.value ?? false;

    // Nuevo intento: se limpia el error anterior, sea cual sea su origen.
    setState(() {
      _loginError = null;
    });

    FocusScope.of(context).unfocus();

    _typingDebounce?.cancel();

    if (hasEmptyField) {
      await _applyLoginError(handsWereUp: handsWereUp);
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
      await _settleAnimation(handsWereUp: handsWereUp);

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
      // Solo un 401 significa credenciales inválidas. La red, el timeout, un
      // 5xx o una respuesta no interpretable se informan aparte para no
      // ocultar fallos de infraestructura tras el mensaje de credenciales.
      await _applyLoginError(
        handsWereUp: handsWereUp,
        message: e.statusCode == 401
            ? _loginErrorMessage
            : _connectionErrorMessage,
      );
    } catch (_) {
      // Excepción inesperada: no se puede afirmar que las credenciales fallen.
      await _applyLoginError(
        handsWereUp: handsWereUp,
        message: _connectionErrorMessage,
      );
    }
  }

  // Único punto de error del login: restablece el estado, muestra el mensaje
  // correspondiente y dispara la animación de fallo del oso.
  Future<void> _applyLoginError({
    required bool handsWereUp,
    String? message,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isSubmitting = false;
      _loginError = message ?? _loginErrorMessage;
    });

    // Igual que en el éxito, el trigger de fallo necesita la máquina en reposo.
    await _settleAnimation(handsWereUp: handsWereUp);

    if (!mounted) return;

    _trigFail?.fire();
  }

  // Diálogo de recuperación de contraseña mediante Firebase.
  // El mensaje mostrado es siempre el mismo, exista o no la cuenta (OWASP).
  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Recuperar contraseña'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'tu@correo.com',
                      errorText: dialogError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = emailController.text.trim();

                    if (email.isEmpty) {
                      setDialogState(() {
                        dialogError = 'Ingresa tu correo';
                      });
                      return;
                    }

                    // Se captura antes del await para no usar `context`
                    // después del hueco asíncrono.
                    final messenger = ScaffoldMessenger.of(this.context);

                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: email,
                      );

                      if (!dialogContext.mounted) return;

                      Navigator.pop(dialogContext);

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Si existe una cuenta asociada a este correo, recibirás las instrucciones para restablecer tu contraseña.',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    } on FirebaseAuthException catch (_) {
                      if (!dialogContext.mounted) return;

                      Navigator.pop(dialogContext);

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Si existe una cuenta asociada a este correo, recibirás las instrucciones para restablecer tu contraseña.',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    } catch (_) {
                      if (!dialogContext.mounted) return;

                      Navigator.pop(dialogContext);

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Si existe una cuenta asociada a este correo, recibirás las instrucciones para restablecer tu contraseña.',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // Aviso de sesión expirada o invalidada por 401; se consume una sola vez.
    _loginError = widget.session.consumeMessage();

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
                    if (_loginError != null) {
                      setState(() {
                        _loginError = null;
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
                    if (_loginError != null) {
                      setState(() {
                        _loginError = null;
                      });
                    }

                    _isHandsUp?.change(true);
                  },
                  decoration: InputDecoration(
                    hintText: 'Password',
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
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Único componente visual de error del login. El mismo mensaje
                // genérico se usa para cualquier fallo del intento.
                if (_loginError != null) ...[
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
                            _loginError!,
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
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
