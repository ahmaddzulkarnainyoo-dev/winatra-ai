import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('winatra_accessibility');
  static const EventChannel _eventChannel = EventChannel('winatra_accessibility_events');

  static final StreamController<String> _textController = StreamController<String>.broadcast();
  static StreamSubscription? _eventSubscription;

  static Stream<String> get textStream => _textController.stream;

  /// Initialize the event listener. Safe to call multiple times.
  static void initialize({bool autoProcess = true}) {
    if (_eventSubscription != null) return;
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) async {
      if (event is String && event.isNotEmpty) {
        _textController.add(event);
        if (autoProcess) await processAccessibilityText(event);
      }
    }, onError: (_) {});
  }

  static Future<String> getSelectedText() async {
    try {
      final text = await _channel.invokeMethod<String>('getSelectedText');
      return text ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<String> getScreenText() async {
    try {
      final text = await _channel.invokeMethod<String>('getScreenText');
      return text ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
  }

  static Future<void> startListening() async {
    try {
      await _channel.invokeMethod('startListening');
    } catch (_) {}
  }

  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (_) {}
  }

  static Future<void> dispose() async {
    try {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      await _textController.close();
    } catch (_) {}
  }

  static Future<void> processText(String text) async {
    try {
      await _channel.invokeMethod('processAccessibilityText', {'text': text});
    } catch (_) {}
  }

  /// Convenience wrapper to send accessibility text to native for AI processing.
  static Future<void> processAccessibilityText(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _channel.invokeMethod('processAccessibilityText', {'text': text});
    } catch (_) {}
  }

  static Future<bool> isServiceEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showResultNotification(String title, String body) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'basic_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
        ),
      );
    } catch (_) {}
  }
}
