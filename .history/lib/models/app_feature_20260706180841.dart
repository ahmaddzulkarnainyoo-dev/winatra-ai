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

  /// Baca status enabled dari SharedPreferences
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('feature_${id}_enabled') ?? true;
  }

  /// Set status enabled ke SharedPreferences
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feature_${id}_enabled', value);
  }
}