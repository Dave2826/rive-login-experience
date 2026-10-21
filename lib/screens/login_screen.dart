import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'dart:async'; //3.1 importar el timer

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;

  StateMachineController? _controller;
  //StateMachine Inputs
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  //3.2 timer para detener el reccorrido de la mirada 
  Timer? _typingDebounce;
  

  // 2.1 Crear variables para FocusNode
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // 2.2 Crear los oyentes (listeners)
  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
          if (_isHandsUp != null) {
          _isHandsUp!.change(false);
          //3.3 mirada neutral
          _numLook?.value = 50.0;
        }
      }
    });
    _passwordFocus.addListener(() {
      //Manos arriba en password
      _isHandsUp?.change(_passwordFocus.hasFocus);
    });

  }


  @override
  Widget build(BuildContext context) {
    // Obtenemos el tamaño de la pantalla para poder hacer un diseño responsivo
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Contiene la animación de Rive
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear-animation.riv',
                    stateMachines: ['Login Machine'],
                    // 1.2 Vingular la animacion
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );
                      // 1.3 verificar que inicio bien
                      if (_controller == null) return;
                      //Agregar el controlador al artboard
                      artboard.addController(_controller!);
                      // 1.4 Vincular las variables
                      _isChecking = _controller!.findSMI('isChecking');
                      _isHandsUp = _controller!.findSMI('isHandsUp');
                      _trigSuccess = _controller!.findSMI('trigSuccess');
                      _trigFail = _controller!.findSMI('trigFail');
                      _numLook = _controller!.findSMI('numLook');
                    },
                  ),
                ),
                // Para separar el RiveAnimation del resto de los elementos
                const 
                // Email
                SizedBox(height: 10),
                // TextField del email, con el tipo de teclado correspondiente
                TextField(
                  // 2.3 asignar el focus al textfield
                  focusNode: _emailFocus,
                  // 1.5 Vincular a campo de texto
                  onChanged: (value) {
                    if(_isHandsUp != null) {
                      // No tapes los ojos al ver el email
                      //_isHandsUp!.change(false);
                    }
                    // Si isChecking es null
                    if (_isChecking == null) return;
                    //Activa el modo chismoso
                    _isChecking!.change(true);
                    // 3.4 Implementar recorrido de mirada
                    // Ajuste de limites del 0 a 100
                    // 80 medida de calibracion
                    final look = (value.length / 80.0 * 100.0).clamp(
                      0.0, 
                      100.0
                    );
                    _numLook?.value = look;

                    //3.5 Debounce: si vuelve a teclear, reinicia el contador
                    _typingDebounce?.cancel();
                    // Crear nuevo timer
                    _typingDebounce = Timer(const Duration(seconds: 3), () {
                      // Si se cierra la pantalla, termina la ejecución 
                      if (!mounted) return;
                      // Mirada neutral
                      _isChecking?.change(false);
                    });

                  },
                  decoration: InputDecoration(
                    hintText: "Email",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const 
                SizedBox(height: 10),
                // Contraseña
                TextField(
                  focusNode: _passwordFocus,
                  // 1.5 Vincular a campo de texto
                  onChanged: (value) {
                    if(_isChecking != null) {
                      // Tapa los ojos al ver la contraseña
                      //_isChecking!.change(false);
                    }
                    // Si isHandsUp es null
                    if (_isHandsUp == null) return;
                    //Activa el modo chismoso
                    _isHandsUp!.change(true);
                  },
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      // Icono para mostrar/ocultar la contraseña
                      icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        // Para refrescar el icono
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    //2.4 Liberar memoria/recurso en los focus node
    _emailFocus.dispose();
    _passwordFocus.dispose();
    //3.5 liberar timer
    _typingDebounce?.cancel();
    super.dispose();
  }
}