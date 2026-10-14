// lib/theme.dart
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// PALETA DE COLORES — MODO OSCURO (Neón Cyberpunk)
// ═══════════════════════════════════════════════════════════
class DarkPalette {
  static const Color bg = Color(0xFF020202);
  static const Color panel = Color(0xFF070707);
  static const Color panel2 = Color(0xFF0D0D0D);
  static const Color border = Color(0xFF202020);
  static const Color cardBg = Color(0xFF0F0F10);
  static const Color cardBgSoft = Color(0xFF17181A);

  static const Color red = Color(0xFFFF1744);
  static const Color yellow = Color(0xFFFFEA00);
  static const Color purple = Color(0xFFB000FF);
  static const Color green = Color(0xFF00FF85);

  static const Color white = Color(0xFFF4F4F5);
  static const Color muted = Color(0xFF77777F);

  static const Color orange = Color(0xFFFF7A00);
  static const Color orangeSoft = Color(0xFFFFA34D);
  static const Color blue = Color(0xFF2FB8FF);
  static const Color cyan = Color(0xFF00E0FF);
  static const Color lime = Color(0xFFB4FF39);
}

// ═══════════════════════════════════════════════════════════
// PALETA DE COLORES — MODO CLARO (Limpio, alto contraste)
// ═══════════════════════════════════════════════════════════
class LightPalette {
  static const Color bg = Color(0xFFF5F5F7);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panel2 = Color(0xFFF0F0F3);
  static const Color border = Color(0xFFE0E0E5);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgSoft = Color(0xFFF8F8FA);

  static const Color red = Color(0xFFE0002B);
  static const Color yellow = Color(0xFFD4A800);
  static const Color purple = Color(0xFF8A00CC);
  static const Color green = Color(0xFF00A855);

  static const Color white = Color(0xFF1A1A1D);
  static const Color muted = Color(0xFF6B6B75);

  static const Color orange = Color(0xFFE06500);
  static const Color orangeSoft = Color(0xFFE08040);
  static const Color blue = Color(0xFF0088CC);
  static const Color cyan = Color(0xFF00A0B8);
  static const Color lime = Color(0xFF7FCC00);
}

// ═══════════════════════════════════════════════════════════
// THEME EXTENSIONS — Para acceder a los colores dinámicamente
// ═══════════════════════════════════════════════════════════
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color panel;
  final Color panel2;
  final Color border;
  final Color cardBg;
  final Color cardBgSoft;

  final Color red;
  final Color yellow;
  final Color purple;
  final Color green;

  final Color white;
  final Color muted;

  final Color orange;
  final Color orangeSoft;
  final Color blue;
  final Color cyan;
  final Color lime;

  const AppColors({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.border,
    required this.cardBg,
    required this.cardBgSoft,
    required this.red,
    required this.yellow,
    required this.purple,
    required this.green,
    required this.white,
    required this.muted,
    required this.orange,
    required this.orangeSoft,
    required this.blue,
    required this.cyan,
    required this.lime,
  });

  static const AppColors dark = AppColors(
    bg: DarkPalette.bg,
    panel: DarkPalette.panel,
    panel2: DarkPalette.panel2,
    border: DarkPalette.border,
    cardBg: DarkPalette.cardBg,
    cardBgSoft: DarkPalette.cardBgSoft,
    red: DarkPalette.red,
    yellow: DarkPalette.yellow,
    purple: DarkPalette.purple,
    green: DarkPalette.green,
    white: DarkPalette.white,
    muted: DarkPalette.muted,
    orange: DarkPalette.orange,
    orangeSoft: DarkPalette.orangeSoft,
    blue: DarkPalette.blue,
    cyan: DarkPalette.cyan,
    lime: DarkPalette.lime,
  );

  static const AppColors light = AppColors(
    bg: LightPalette.bg,
    panel: LightPalette.panel,
    panel2: LightPalette.panel2,
    border: LightPalette.border,
    cardBg: LightPalette.cardBg,
    cardBgSoft: LightPalette.cardBgSoft,
    red: LightPalette.red,
    yellow: LightPalette.yellow,
    purple: LightPalette.purple,
    green: LightPalette.green,
    white: LightPalette.white,
    muted: LightPalette.muted,
    orange: LightPalette.orange,
    orangeSoft: LightPalette.orangeSoft,
    blue: LightPalette.blue,
    cyan: LightPalette.cyan,
    lime: LightPalette.lime,
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? panel,
    Color? panel2,
    Color? border,
    Color? cardBg,
    Color? cardBgSoft,
    Color? red,
    Color? yellow,
    Color? purple,
    Color? green,
    Color? white,
    Color? muted,
    Color? orange,
    Color? orangeSoft,
    Color? blue,
    Color? cyan,
    Color? lime,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      panel: panel ?? this.panel,
      panel2: panel2 ?? this.panel2,
      border: border ?? this.border,
      cardBg: cardBg ?? this.cardBg,
      cardBgSoft: cardBgSoft ?? this.cardBgSoft,
      red: red ?? this.red,
      yellow: yellow ?? this.yellow,
      purple: purple ?? this.purple,
      green: green ?? this.green,
      white: white ?? this.white,
      muted: muted ?? this.muted,
      orange: orange ?? this.orange,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      blue: blue ?? this.blue,
      cyan: cyan ?? this.cyan,
      lime: lime ?? this.lime,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panel2: Color.lerp(panel2, other.panel2, t)!,
      border: Color.lerp(border, other.border, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBgSoft: Color.lerp(cardBgSoft, other.cardBgSoft, t)!,
      red: Color.lerp(red, other.red, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      green: Color.lerp(green, other.green, t)!,
      white: Color.lerp(white, other.white, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      lime: Color.lerp(lime, other.lime, t)!,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// THEME DATA — Para MaterialApp
// ═══════════════════════════════════════════════════════════
class AppTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkPalette.bg,
      primaryColor: DarkPalette.red,
      colorScheme: const ColorScheme.dark(
        primary: DarkPalette.red,
        secondary: DarkPalette.purple,
        surface: DarkPalette.panel,
        error: DarkPalette.red,
      ),
      extensions: const <ThemeExtension<dynamic>>[AppColors.dark],
      fontFamily: 'Roboto',
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: LightPalette.bg,
      primaryColor: LightPalette.red,
      colorScheme: const ColorScheme.light(
        primary: LightPalette.red,
        secondary: LightPalette.purple,
        surface: LightPalette.panel,
        error: LightPalette.red,
      ),
      extensions: const <ThemeExtension<dynamic>>[AppColors.light],
      fontFamily: 'Roboto',
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HELPER EXTENSION — Acceso rápido: context.colors.red
// ═══════════════════════════════════════════════════════════
extension ThemeColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
