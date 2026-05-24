import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityPrefs {
  static const _key = 'accessibility_mode';

  static Future<bool> isEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_key) ?? false; 
}

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}