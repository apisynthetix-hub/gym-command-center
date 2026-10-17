// lib/design/tokens.dart
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════
/// SPACING — escala de 4pt. Usa SOLO estos valores.
/// ═══════════════════════════════════════════════════════════
class Sp {
  Sp._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

/// ═══════════════════════════════════════════════════════════
/// RADIUS — 4 valores. Nada más.
/// ═══════════════════════════════════════════════════════════
class Rd {
  Rd._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
}

/// ═══════════════════════════════════════════════════════════
/// TIPOGRAFÍA — 4 pesos: 500, 600, 800, 900.
/// ═══════════════════════════════════════════════════════════
class Tx {
  Tx._();

  static const display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.05,
  );

  static const h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const h2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static const h3 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.8,
  );

  static const numberXL = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    height: 1.0,
  );

  static const numberLg = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    height: 1.0,
  );

  static const numberMd = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    height: 1.0,
  );
}

/// ═══════════════════════════════════════════════════════════
/// DURACIONES
/// ═══════════════════════════════════════════════════════════
class Dur {
  Dur._();
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 500);
  static const gauge = Duration(milliseconds: 1400);
}

/// ═══════════════════════════════════════════════════════════
/// CURVAS
/// ═══════════════════════════════════════════════════════════
class Curves2 {
  Curves2._();
  static const smooth = Curves.easeOutCubic;
  static const bounce = Curves.easeOutBack;
  static const gentle = Curves.easeInOut;
}
