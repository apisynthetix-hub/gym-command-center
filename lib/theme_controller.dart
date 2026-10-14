// lib/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════
// CONTROLADOR GLOBAL DEL TEMA
// ═══════════════════════════════════════════════════════════
class ThemeController extends ChangeNotifier {
  static const String _prefsKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);

      if (saved == null) {
        _themeMode = ThemeMode.dark;
      } else {
        switch (saved) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
          case 'dark':
          default:
            _themeMode = ThemeMode.dark;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error cargando tema: $e');
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      };
      await prefs.setString(_prefsKey, value);
    } catch (e) {
      debugPrint('❌ Error guardando tema: $e');
    }
  }

  Future<void> toggle() async {
    await setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> useSystem() async {
    await setTheme(ThemeMode.system);
  }
}

// ═══════════════════════════════════════════════════════════
// INSTANCIA GLOBAL SINGLETON
// ═══════════════════════════════════════════════════════════
final ThemeController themeController = ThemeController();
