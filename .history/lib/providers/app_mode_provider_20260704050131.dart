import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global state for online/offline mode and dynamic theming.
class AppModeProvider extends ChangeNotifier {
  static const _key = 'offline_mode_enabled';

  bool _isOffline = false;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;

  // ── Online theme (purple) ──
  Color get primaryColor => isOffline ? const Color(0xFF00CC88) : const Color(0xFF6B4EFF);
  Color get accentColor => isOffline ? const Color(0xFF00FFAA) : const Color(0xFF9B7EFF);
  Color get surfaceColor => isOffline ? const Color(0xFF1A2E1A) : const Color(0xFF1A1A2E);
  Color get bgColor => const Color(0xFF0D0D1A);
  Color get textColor => const Color(0xFFCCCCCC);
  Color get headerTextColor => isOffline ? const Color(0xFF00FFAA) : const Color(0xFF9B7EFF);
  Color get cardBorderColor => isOffline ? const Color(0xFF00CC88) : const Color(0xFF6B4EFF);
  Color get successColor => const Color(0xFF4CAF50);
  Color get errorColor => const Color(0xFFFF5252);

  /// Load saved preference
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isOffline = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Toggle mode
  Future<void> toggle() async {
    _isOffline = !_isOffline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isOffline);
    notifyListeners();
  }

  /// Set mode directly
  Future<void> setOffline(bool value) async {
    if (_isOffline == value) return;
    _isOffline = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isOffline);
    notifyListeners();
  }
}