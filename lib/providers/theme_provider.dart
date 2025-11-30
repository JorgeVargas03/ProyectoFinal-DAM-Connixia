import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _colorKey = 'seed_color'; // Nueva clave para el color

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.indigo; // Color por defecto

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar Modo
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
            (e) => e.toString() == savedTheme,
        orElse: () => ThemeMode.system,
      );
    }

    // Cargar Color
    final savedColor = prefs.getInt(_colorKey);
    if (savedColor != null) {
      _seedColor = Color(savedColor);
    }

    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  void toggleDarkMode() {
    setTheme(_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  // Nueva función para cambiar el color
  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.value);
  }
}