import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeStore {
  static const _themeModeKey = 'theme_mode';

  Future<ThemeMode?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_themeModeKey);

    return switch (storedValue) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => null,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    });
  }
}
