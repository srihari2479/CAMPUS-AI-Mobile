import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import 'api_service.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messages,
  });
}

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  final List<ChatSession> _history = [];
  bool _isLoading = false;
  String _activeSessionId = '';
  final ApiService _apiService = ApiService();

  List<ChatMessage> get messages => _messages;
  List<ChatSession> get history => _history;
  bool get isLoading => _isLoading;
  String get activeSessionId => _activeSessionId;

  Future<void> sendChatMessage(
    String query, {
    String? courseId,
    String? docType,
  }) async {
    final text = query.trim();
    if (text.isEmpty || _isLoading) return;

    // Ensure session ID exists
    if (_activeSessionId.isEmpty || _messages.isEmpty) {
      _activeSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // 1. Add user message & immediately save session state
    final userMessage = ChatMessage(content: text, isUser: true);
    _messages.add(userMessage);
    _isLoading = true;
    _saveCurrentSession();
    notifyListeners();

    try {
      // 2. Fetch answer from CRAG backend API / Fallbacks
      final result = await _apiService.sendQuery(
        query: text,
        courseId: courseId,
        docType: docType,
      );

      // 3. Add assistant response
      final assistantMessage = ChatMessage.fromMap(result, isUser: false);
      _messages.add(assistantMessage);
    } catch (e) {
      // Handle connection or API errors gracefully without resetting session
      debugPrint('ChatProvider query error: $e');
      final errorMessage = ChatMessage(
        content: 'Unable to connect to campus AI server. Please check network connection and try again.',
        isUser: false,
      );
      _messages.add(errorMessage);
    } finally {
      _isLoading = false;
      _saveCurrentSession(); // Always persist session state
      notifyListeners();
    }
  }

  void _saveCurrentSession() {
    if (_messages.isEmpty || _activeSessionId.isEmpty) return;
    final firstUserMsg = _messages.firstWhere((m) => m.isUser, orElse: () => _messages.first);
    final title = firstUserMsg.content.length > 28
        ? '${firstUserMsg.content.substring(0, 28)}…'
        : firstUserMsg.content;

    final existingIndex = _history.indexWhere((s) => s.id == _activeSessionId);
    final session = ChatSession(
      id: _activeSessionId,
      title: title,
      timestamp: DateTime.now(),
      messages: List.from(_messages),
    );

    if (existingIndex >= 0) {
      _history[existingIndex] = session;
    } else {
      _history.insert(0, session);
    }
  }

  void startNewChat() {
    // Only save if there are messages
    if (_messages.isNotEmpty && _activeSessionId.isNotEmpty) {
      _saveCurrentSession();
    }
    _messages = [];
    _activeSessionId = '';
    _isLoading = false;
    notifyListeners();
  }

  void loadSession(ChatSession session) {
    // Save previous active session before switching
    if (_messages.isNotEmpty && _activeSessionId.isNotEmpty) {
      _saveCurrentSession();
    }
    _activeSessionId = session.id;
    _messages = List.from(session.messages);
    _isLoading = false;
    notifyListeners();
  }

  void deleteSession(String sessionId) {
    _history.removeWhere((s) => s.id == sessionId);
    if (_activeSessionId == sessionId) {
      _messages = [];
      _activeSessionId = '';
      _isLoading = false;
    }
    notifyListeners();
  }

  void clearChat() {
    startNewChat();
  }
}