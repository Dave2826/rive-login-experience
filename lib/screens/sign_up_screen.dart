import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    String? emailError;
    String? passwordError;
    String? confirmPasswordError;

    if (email.isEmpty) {
      emailError = 'El correo es obligatorio';
    } else if (!email.endsWith('@tecdesoftware.edu.mx')) {
      emailError = 'Usa tu correo institucional (@tecdesoftware.edu.mx)';
    }

    if (password.isEmpty) {
      passwordError = 'La contraseña es obligatoria';
    } else if (password.length < 8) {
      passwordError = 'Mínimo 8 caracteres';
    } else if (!RegExp(r'[A-Z]').hasMatch(password)) {
      passwordError = 'Debe incluir al menos una mayúscula';
    } else if (!RegExp(r'[a-z]').hasMatch(password)) {
      passwordError = 'Debe incluir al menos una minúscula';
    } else if (!RegExp(r'[0-9]').hasMatch(password)) {
      passwordError = 'Debe incluir al menos un número';
    } else if (!RegExp(r'[@$!%*?&]').hasMatch(password)) {
      passwordError = 'Debe incluir al menos un símbolo (@\$!%*?&)';
    }

    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Confirma tu contraseña';
    } else if (confirmPassword != password) {
      confirmPasswordError = 'Las contraseñas no coinciden';
    }

    if (emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _confirmPasswordError = confirmPasswordError;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _emailError = 'Este correo ya está registrado';
        } else if (e.code == 'invalid-email') {
          _emailError = 'Correo inválido';
        } else if (e.code == 'weak-password') {
          _passwordError = 'Contraseña muy débil';
        } else {
          _emailError = 'Error al crear cuenta: ${e.message}';
        }
      });
    } catch (_) {
      setState(() {
        _emailError = 'Error inesperado al crear cuenta';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo institucional',
                hintText: 'usuario@tecdesoftware.edu.mx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_emailError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _emailError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_passwordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _passwordError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 8),

            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Mínimo 8 caracteres',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '• Al menos una letra mayúscula',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '• Al menos una letra minúscula',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '• Al menos un número',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '• Al menos un símbolo (@\$!%*?&)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (_confirmPasswordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _confirmPasswordError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSignUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    : const Text('Crear cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
