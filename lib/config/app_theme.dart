import 'package:flutter/material.dart';

/// Colores únicos para la app (útiles para pruebas y consistencia).
abstract final class AppColors {
  static const Color primary   = Color(0xFFEC407A);  // rosa viejo (login CTA, gate spinner)
  static const Color secondary = Color(0xFF1E88E5);  // azul (AppBar, chips)
  static const Color success   = Color(0xFF4CAF50);  // verde (snackbar OK)
  static const Color error     = Color(0xFFE53935);  // rojo (textos de error)
  static const Color muted     = Color(0xFF757575);  // gris (ayudas, vacío)
}

/// Tema centralizado. Copia los valores visuales reales actuales para que
/// el cambio sea puramente de estructura; no altera el aspecto de producción.
ThemeData lightTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)
      .copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: Colors.white,
      ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.secondary,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(AppColors.primary),
      foregroundColor: WidgetStatePropertyAll(Colors.white),
      padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(vertical: 16)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      )),
    ),
  ),
  cardTheme: CardThemeData(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.success,
  ),
  scaffoldBackgroundColor: Colors.white,
);