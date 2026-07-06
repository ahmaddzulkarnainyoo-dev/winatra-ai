import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State management for the Active Assistant mode ("Asisten Aktif").
/// Controls:
/// - Whether the assistant feature is active (toggle ON/OFF)
/// - Whether the user has seen the onboarding animation
/// - Whether the robot is hidden/shown
/// - Session context for multi-step commands
class AssistantActiveProvider extends ChangeNotifier {
  static const String _prefKeyActive = 'assistant_active';
  static const String _prefKeyOnboarding = 'assistant_onboarding_seen';
  static const String _prefKeyRobotHidden = 'assistant_robot_hidden';
  static const String _prefKeyVoiceEnabled = 'voice_enabled';

  bool _isActive = false;
  bool _hasSeenOnboarding = false;
  bool _isRobotHidden = false;
  bool _isVoiceEnabled = true;

  // Session context for multi-step commands
  String _currentScreen = 'home';
  bool _isLoggedIn = false;
  String _lastActionResult = '';
  Map<String, String> _sessionContext = {};

  bool get isActive => _isActive;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isRobotHidden => _isRobotHidden;
  bool get isVoiceEnabled => _isVoiceEnabled;
  String get currentScreen => _currentScreen;
  bool get isLoggedIn => _isLoggedIn;
  String get lastActionResult => _lastActionResult;
  Map<String, String> get sessionContext => Map.unmodifiable(_sessionContext);

  /// Load persisted state from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isActive = prefs.getBool(_prefKeyActive) ?? false;
    _hasSeenOnboarding = prefs.getBool(_prefKeyOnboarding) ?? false;
    _isRobotHidden = prefs.getBool(_prefKeyRobotHidden) ?? false;
    _isVoiceEnabled = prefs.getBool(_prefKeyVoiceEnabled) ?? true;
    notifyListeners();
  }

  /// Toggle the entire Active Assistant mode
  Future<void> setActive(bool value) async {
    if (_isActive == value) return;
    _isActive = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyActive, value);
    notifyListeners();
  }

  /// Mark onboarding as seen (only happens once)
  Future<void> markOnboardingSeen() async {
    if (_hasSeenOnboarding) return;
    _hasSeenOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyOnboarding, true);
    notifyListeners();
  }

  /// Reset onboarding (for testing purposes)
  Future<void> resetOnboarding() async {
    _hasSeenOnboarding = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyOnboarding, false);
    notifyListeners();
  }

  /// Hide the robot (tap & hold → "Sembunyikan")
  Future<void> hideRobot() async {
    _isRobotHidden = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyRobotHidden, true);
    notifyListeners();
  }

  /// Show the robot (via Settings or double-tap gesture)
  Future<void> showRobot() async {
    _isRobotHidden = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyRobotHidden, false);
    notifyListeners();
  }

  /// Toggle voice input/output
  Future<void> setVoiceEnabled(bool value) async {
    if (_isVoiceEnabled == value) return;
    _isVoiceEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyVoiceEnabled, value);
    notifyListeners();
  }

  // ── Session Context Methods ──

  /// Update current screen context (e.g., "home", "elearning", "whatsapp")
  void setCurrentScreen(String screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  /// Set login status
  void setLoggedIn(bool value) {
    _isLoggedIn = value;
    notifyListeners();
  }

  /// Store last action result (for follow-up commands)
  void setLastActionResult(String result) {
    _lastActionResult = result;
    notifyListeners();
  }

  /// Store arbitrary session context
  void setContext(String key, String value) {
    _sessionContext[key] = value;
    notifyListeners();
  }

  /// Get a context value
  String? getContext(String key) => _sessionContext[key];

  /// Clear all session context
  void clearSessionContext() {
    _sessionContext.clear();
    _currentScreen = 'home';
    _lastActionResult = '';
    notifyListeners();
  }

  /// Clear specific context key
  void removeContext(String key) {
    _sessionContext.remove(key);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}