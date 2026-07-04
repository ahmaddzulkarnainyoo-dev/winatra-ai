import 'dart:convert';
import 'package:hive/hive.dart';

/// Service for persisting chat history using Hive.
/// Each chat session is stored as a JSON string in Hive.
class ChatHistoryService {
  static const String _boxName = 'chat_history';
  static const String _prefsKey = 'chat_messages';

  static Box? _box;

  /// Initialize the Hive box for chat history.
  static Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Save a list of messages to persistent storage.
  static Future<void> saveMessages(List<Map<String, String>> messages) async {
    try {
      final jsonList = messages.map((m) => jsonEncode(m)).toList();
      await _box?.put(_prefsKey, jsonList);
    } catch (e) {
      print('ChatHistoryService: Error saving messages: $e');
    }
  }

  /// Load messages from persistent storage.
  static List<Map<String, String>> loadMessages() {
    try {
      final jsonList = _box?.get(_prefsKey) as List<dynamic>?;
      if (jsonList == null) return [];

      return jsonList.map((json) {
        final map = jsonDecode(json as String) as Map<String, dynamic>;
        return {
          'sender': map['sender'] as String? ?? '',
          'text': map['text'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      print('ChatHistoryService: Error loading messages: $e');
      return [];
    }
  }

  /// Clear all saved chat history.
  static Future<void> clearHistory() async {
    try {
      await _box?.delete(_prefsKey);
    } catch (e) {
      print('ChatHistoryService: Error clearing history: $e');
    }
  }
}