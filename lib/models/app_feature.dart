import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model untuk fitur yang bisa di-toggle on/off di Beranda.
class AppFeature {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final WidgetBuilder detailPage;

  AppFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.detailPage,
  });

  /// Key SharedPreferences yang digunakan untuk fitur ini
  String get prefsKey {
    switch (id) {
      case 'notification':
        return 'notif_enabled';
      case 'keyboard':
        return 'keyboard_enabled';
      case 'chat':
        return 'chat_enabled';
      default:
        return 'feature_${id}_enabled';
    }
  }

  /// Baca status enabled dari SharedPreferences
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? true;
  }

  /// Set status enabled ke SharedPreferences
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }
}