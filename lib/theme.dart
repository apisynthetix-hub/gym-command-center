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
        bg: Color(0xFF0A0A0A),
        panel: Color(0xFF1A1A1A),
        panel2: Color(0xFF252525),
        border: Color(0xFF2A2A2A),
        white: Colors.white,
        muted: Color(0xFF888888),
        red: Color(0xFFFF1744),
        green: Color(0xFF00E676),
        blue: Color(0xFF2979FF),
        yellow: Color(0xFFFFEA00),
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
        red: Color(0xFFD50000),
        green: Color(0xFF00C853),
        blue: Color(0xFF2962FF),
        yellow: Color(0xFFFFAB00),
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
        primary: Color(0xFFD50000),
        secondary: Color(0xFF00C853),
      ),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF1744),
        secondary: Color(0xFF00E676),
      ),
      fontFamily: 'Roboto',
    );
  }
}
