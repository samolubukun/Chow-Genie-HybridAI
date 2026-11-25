import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/model_manager.dart';
import '../services/image_service.dart';
import '../services/kitchen_agent_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ModelManager _modelManager;
  final ImageService _imageService;
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  bool _isGenerating = false;
  String? _errorMessage;
  String? _contextPrompt;

  static const String _historyKey = 'smf_chat_history';

  ChatViewModel(this._modelManager, this._imageService) {
    _loadSessions();
  }

  List<ChatMessage> get messages => _messages;
  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  bool get hasMessages => _messages.isNotEmpty;
  String? get contextPrompt => _contextPrompt;

  void setContext(String context) {
    _contextPrompt = context;
    if (_messages.isEmpty) {
      _messages.add(ChatMessage.system(
        content: 'I have context about your meal. Ask me anything about it!\n\n$context',
      ));
      notifyListeners();
    }
  }

  void clearContext() {
    _contextPrompt = null;
    notifyListeners();
  }

  Future<void> createNewSession({String? initialTitle}) async {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: initialTitle ?? 'New Chat',
      createdAt: DateTime.now(),
    );
    _sessions.insert(0, newSession);
    _currentSession = newSession;
    _messages.clear();
    notifyListeners();
    await _saveSessionsList();
    await _saveCurrentSessionMessages();
  }

  Future<void> selectSession(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    _currentSession = session;
    await _loadCurrentSessionMessages();
  }

  Future<void> deleteSession(String sessionId) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    _sessions.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('smf_chat_session_messages_$sessionId');
    await _saveSessionsList();

    if (_currentSession?.id == sessionId) {
      if (_sessions.isNotEmpty) {
        _currentSession = _sessions.first;
        await _loadCurrentSessionMessages();
      } else {
        await createNewSession();
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isGenerating) return;
    _errorMessage = null;

    final List<ChatMessage> history = [];
    history.add(ChatMessage.system(
      content: "You are ChowGenie, an expert AI chef and nutrition assistant. Your goal is to help users generate recipes from ingredients, analyze food photos, design healthy meals, track nutrition, suggest dietary remedies, and give recipe recommendations. You specialize in creating delicious, practical recipes with step-by-step instructions. Please keep answers concise, practical, and focused strictly on food, cooking, health, and diet. Do not answer questions outside of nutrition/food.",
    ));
    history.addAll(_messages);

    final userMsg = ChatMessage.user(content: content.trim());
    _messages.add(userMsg);
    notifyListeners();

    if (_currentSession != null && _currentSession!.title == 'New Chat' && _messages.length == 1) {
      final firstMsg = content.trim();
      final words = firstMsg.split(' ');
      final title = words.take(4).join(' ') + (words.length > 4 ? '...' : '');
      _currentSession!.title = title;
      await _saveSessionsList();
    }

    _isGenerating = true;
    notifyListeners();

    try {
      // 1. Process via Kitchen Agent (Timer, Shopping List, Pantry, Meal Planner actions)
      final agentResponse = await KitchenAgentService.instance.processCommand(content.trim());
      if (agentResponse.actionType != AgentActionType.none) {
        _messages.add(ChatMessage.ai(
          content: agentResponse.displayText,
          modelName: _modelManager.latestModelName,
          isOnDevice: _modelManager.isLatestOnDevice,
        ));
      } else {
        // 2. Fall back to standard conversational response
        final response = await _modelManager.generateResponse(
          content.trim(),
          history: history,
        );
        if (response != null) {
          _messages.add(ChatMessage.ai(
            content: response,
            modelName: _modelManager.latestModelName,
            isOnDevice: _modelManager.isLatestOnDevice,
          ));
        } else {
          _setError('Failed to generate response');
        }
      }
    } catch (e) {
      _setError('Error: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
    await _saveCurrentSessionMessages();
  }

  Future<void> sendMultimodalMessage(
    String content,
    String? imagePath, {
    List<String> imagePaths = const [],
  }) async {
    if (_isGenerating) return;
    _errorMessage = null;

    final effectivePaths = imagePaths.isNotEmpty
        ? imagePaths
        : (imagePath != null ? [imagePath] : <String>[]);
    if (effectivePaths.isEmpty) return;

    final List<ChatMessage> history = [];
    history.add(ChatMessage.system(
      content: "You are ChowGenie, an expert AI chef and nutrition assistant. Your goal is to help users generate recipes from ingredients, analyze food photos, design healthy meals, track nutrition, suggest dietary remedies, and give recipe recommendations. You specialize in creating delicious, practical recipes with step-by-step instructions. Please keep answers concise, practical, and focused strictly on food, cooking, health, and diet. Do not answer questions outside of nutrition/food.",
    ));
    history.addAll(_messages);

    final userMsg = ChatMessage.user(
      content: content.trim(),
      imagePath: effectivePaths.first,
      imagePaths: effectivePaths,
    );
    _messages.add(userMsg);
    notifyListeners();

    if (_currentSession != null && _currentSession!.title == 'New Chat' && _messages.length == 1) {
      final firstMsg = content.trim().isEmpty ? "Analyzed Images" : content.trim();
      final words = firstMsg.split(' ');
      final title = words.take(4).join(' ') + (words.length > 4 ? '...' : '');
      _currentSession!.title = title;
      await _saveSessionsList();
    }

    _isGenerating = true;
    notifyListeners();

    try {
      final List<Uint8List> allBytes = [];
      for (final path in effectivePaths) {
        final b = await _imageService.getBytes(path);
        if (b != null) allBytes.add(b);
      }
      if (allBytes.isEmpty) throw Exception('Failed to read image bytes');

      final prompt = content.trim().isEmpty
          ? 'Analyze these food images in detail. Identify all ingredients and dishes, estimate portions, and provide nutritional and culinary insights.'
          : content.trim();

      final response = await _modelManager.generateMultimodalResponse(
        prompt,
        allBytes,
        history: history,
      );
      if (response != null) {
        _messages.add(ChatMessage.ai(
          content: response,
          modelName: _modelManager.latestModelName,
          isOnDevice: _modelManager.isLatestOnDevice,
        ));
      } else {
        _setError('Failed to generate response');
      }
    } catch (e) {
      _setError('Error: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
    await _saveCurrentSessionMessages();
  }

  Future<String?> pickImage() async {
    return await _imageService.pickFromGallery();
  }

  Future<List<String>> pickMultipleImages() async {
    return await _imageService.pickMultipleFromGallery();
  }

  Future<String?> takePhoto() async {
    return await _imageService.pickFromCamera();
  }

  Future<void> clearConversation() async {
    _messages.clear();
    _errorMessage = null;
    notifyListeners();
    await _saveCurrentSessionMessages();
  }

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Migrate legacy single-chat history
      final oldRaw = prefs.getString(_historyKey);
      if (oldRaw != null) {
        final List<dynamic> oldList = jsonDecode(oldRaw);
        if (oldList.isNotEmpty) {
          final migratedSession = ChatSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Saved Conversation',
            createdAt: DateTime.now(),
          );
          _sessions.add(migratedSession);
          final List<ChatMessage> migratedMessages = oldList.map((m) => ChatMessage.fromJson(m)).toList();
          _messages.addAll(migratedMessages);
          await prefs.setString('smf_chat_session_messages_${migratedSession.id}', jsonEncode(oldList));
          await _saveSessionsList();
          await prefs.remove(_historyKey);
          _currentSession = migratedSession;
          // Always start fresh after migration
          await createNewSession();
          return;
        }
        await prefs.remove(_historyKey);
      }

      // Load persisted sessions list
      final sessionsRaw = prefs.getString('smf_chat_sessions_list');
      if (sessionsRaw != null) {
        final List<dynamic> list = jsonDecode(sessionsRaw);
        _sessions.clear();
        for (final item in list) {
          _sessions.add(ChatSession.fromJson(item));
        }
      }

      if (_sessions.isEmpty) {
        // No sessions at all — create fresh
        await createNewSession();
      } else {
        // Check if the most recent session (index 0) is empty
        final newestSession = _sessions.first;
        final newestKey = 'smf_chat_session_messages_${newestSession.id}';
        final newestRaw = prefs.getString(newestKey);
        final hasMessages = newestRaw != null && newestRaw != '[]' && newestRaw.isNotEmpty;

        if (!hasMessages) {
          // Reuse the empty session — no need to create another blank one
          _currentSession = newestSession;
          _messages.clear();
          notifyListeners();
        } else {
          // Last session has messages — start a fresh new one
          await createNewSession();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSessionsList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _sessions.map((s) => s.toJson()).toList();
      await prefs.setString('smf_chat_sessions_list', jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _saveCurrentSessionMessages() async {
    if (_currentSession == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((m) => m.toJson()).toList();
      await prefs.setString('smf_chat_session_messages_${_currentSession!.id}', jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _loadCurrentSessionMessages() async {
    if (_currentSession == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('smf_chat_session_messages_${_currentSession!.id}');
      _messages.clear();
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        for (final item in list) {
          _messages.add(ChatMessage.fromJson(item));
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
