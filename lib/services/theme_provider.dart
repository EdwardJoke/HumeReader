import 'package:flutter/foundation.dart';
import 'package:hume/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdateChannel { stable, beta }

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  static const String _colorKey = 'seed_color';
  static const String _updateChannelKey = 'update_channel';

  bool _isDarkMode = false;
  ColorSeed _selectedColor = ColorSeed.deepPurple;
  UpdateChannel _updateChannel = UpdateChannel.stable;
  SharedPreferences? _prefs;

  bool get isDarkMode => _isDarkMode;
  ColorSeed get selectedColor => _selectedColor;
  UpdateChannel get updateChannel => _updateChannel;

  Future<void> loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs!.getBool(_themeKey) ?? false;
    final colorIndex = _prefs!.getInt(_colorKey) ?? 0;
    _selectedColor = ColorSeed.values[colorIndex];
    final updateChannelIndex = _prefs!.getInt(_updateChannelKey) ?? 0;
    if (updateChannelIndex >= 0 &&
        updateChannelIndex < UpdateChannel.values.length) {
      _updateChannel = UpdateChannel.values[updateChannelIndex];
    }
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

  Future<void> selectUpdateChannel(UpdateChannel channel) async {
    _updateChannel = channel;
    await _prefs?.setInt(
      _updateChannelKey,
      UpdateChannel.values.indexOf(channel),
    );
    notifyListeners();
  }
}
