// lib/theme.dart
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// EXTENSIÓN DE COLORES DINÁMICOS
// ═══════════════════════════════════════════════════════════
extension ThemeColors on BuildContext {
  AppColorScheme get colors {
    // Si el controlador dice que es oscuro, devolvemos los colores oscuros
    if (Theme.of(this).brightness == Brightness.dark) {
      return const AppColorScheme(
        bg: Color(0xFF090D0C),
        panel: Color(0xFF121918),
        panel2: Color(0xFF1A2421),
        border: Color(0xFF2C3B35),
        white: Colors.white,
        muted: Color(0xFF888888),
        red: Color(0xFFD96972),
        green: Color(0xFF20B8A8),
        blue: Color(0xFF20B8A8),
        yellow: Color(0xFFD7A84E),
      );
    } else {
      // Si es claro, devolvemos colores claros
      return const AppColorScheme(
        bg: Color(0xFFF5F5F5),
        panel: Color(0xFFFFFFFF),
        panel2: Color(0xFFEEEEEE),
        border: Color(0xFFDDDDDD),
        white: Color(0xFF121212),
        muted: Color(0xFF666666),
        red: Color(0xFFBD4A50),
        green: Color(0xFF168F84),
        blue: Color(0xFF168F84),
        yellow: Color(0xFFB17B22),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// CLASE DE COLORES PERSONALIZADOS
// (Le cambié el nombre a AppColorScheme para no chocar con Flutter)
// ═══════════════════════════════════════════════════════════
class AppColorScheme {
  final Color bg;
  final Color panel;
  final Color panel2;
  final Color border;
  final Color white;
  final Color muted;
  final Color red;
  final Color green;
  final Color blue;
  final Color yellow;

  const AppColorScheme({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.border,
    required this.white,
    required this.muted,
    required this.red,
    required this.green,
    required this.blue,
    required this.yellow,
  });
}

// ═══════════════════════════════════════════════════════════
// TEMAS GLOBALES
// (Ahora usan el ColorScheme REAL de Flutter)
// ═══════════════════════════════════════════════════════════
class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF168F84),
        secondary: Color(0xFF20B8A8),
      ),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF20B8A8),
        secondary: Color(0xFF168F84),
      ),
      fontFamily: 'Roboto',
    );
  }
}
