import 'package:flutter/foundation.dart';
import 'package:hume/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  static const String _colorKey = 'seed_color';

  bool _isDarkMode = false;
  ColorSeed _selectedColor = ColorSeed.deepPurple;
  SharedPreferences? _prefs;

  bool get isDarkMode => _isDarkMode;
  ColorSeed get selectedColor => _selectedColor;

  Future<void> loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs!.getBool(_themeKey) ?? false;
    final colorIndex = _prefs!.getInt(_colorKey) ?? 0;
    _selectedColor = ColorSeed.values[colorIndex];
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    await _prefs?.setBool(_themeKey, value);
    notifyListeners();
  }

  Future<void> selectColor(ColorSeed color) async {
    _selectedColor = color;
    await _prefs?.setInt(_colorKey, ColorSeed.values.indexOf(color));
    notifyListeners();
  }
}
