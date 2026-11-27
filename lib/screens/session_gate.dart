import 'dart:async';

import 'package:flutter/material.dart';

import '../services/product_service.dart';
import '../services/session_controller.dart';
import 'login_screen.dart';
import 'products_screen.dart';

/// Decide qué pantalla mostrar según el estado de la sesión.
///
/// Sustituye a la navegación imperativa: al restaurar, expirar o cerrar
/// sesión, el árbol pasa del catálogo al login sin dejar pantallas apiladas.
class SessionGate extends StatefulWidget {
  final SessionController session;

  /// Servicio inyectable para pruebas; en producción se usa [ProductService].
  final ProductService? productService;

  /// Animación inyectable para las pruebas del login; por defecto usa Rive.
  final Widget? loginAnimation;

  const SessionGate({
    super.key,
    required this.session,
    this.productService,
    this.loginAnimation,
  });

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();

    unawaited(widget.session.restore());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        switch (widget.session.status) {
          case SessionStatus.restoring:
            return const _RestoringScreen();
          case SessionStatus.authenticated:
            return ProductsScreen(
              key: ValueKey<String>(widget.session.token ?? ''),
              session: widget.session,
              productService: widget.productService,
            );
          case SessionStatus.unauthenticated:
            return LoginScreen(
              session: widget.session,
              animation: widget.loginAnimation,
            );
        }
      },
    );
  }
}

/// Pantalla breve mientras se lee el token guardado.
class _RestoringScreen extends StatelessWidget {
  const _RestoringScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
    );
  }
}
