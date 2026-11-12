import 'dart:async';

import 'package:flutter/material.dart';

import 'di/container.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  AppState(this.container) {
    _initialize();
  }

  final AppContainer container;
  ThemeMode themeMode = ThemeMode.dark;
  int navigationIndex = 0;
  PdfDocumentModel? selectedDocument;
  PdfDocumentDetails? selectedDetails;
  String activeTool = 'Reader';
  bool chatOpen = true;
  bool isProcessing = false;
  bool isLoading = true;
  String? errorMessage;
  String provider = 'OpenAI';
  String model = 'gpt-4o-mini';
  String apiKey = '';
  final searchController = TextEditingController();
  final chatController = TextEditingController();
  List<PdfDocumentModel> documents = const [];
  final chatMessages = <ChatMessage>[];

  Future<void> _initialize() async {
    try {
      await container.start();
      await refreshDocuments();
    } catch (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDocuments() async {
    isLoading = true;
    notifyListeners();
    try {
      documents = await container.documents.list(
        query: searchController.text.trim(),
        favorites: navigationIndex == 2,
      );
      isLoading = false;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDocument(PdfDocumentModel document) async {
    selectedDocument = document;
    selectedDetails = null;
    navigationIndex = 0;
    errorMessage = null;
    notifyListeners();
    try {
      selectedDetails = await container.documents.open(document);
    } catch (error) {
      errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> importDocument(String path) async {
    try {
      final document = await container.documents.upsert(path);
      await refreshDocuments();
      await selectDocument(document);
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  void setNavigation(int index) {
    navigationIndex = index;
    if (index == 0 || index == 1 || index == 2) {
      unawaited(refreshDocuments());
    }
    notifyListeners();
  }

  void setTool(String tool) {
    activeTool = tool;
    if (tool == 'AI Assistant') chatOpen = true;
    notifyListeners();
  }

  void toggleChat() {
    chatOpen = !chatOpen;
    notifyListeners();
  }

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> toggleFavorite(PdfDocumentModel document) async {
    try {
      await container.sidecar.request('library.upsert', {
        'path': document.path,
        'title': document.name,
        'favorite': !document.favorite,
      });
      await refreshDocuments();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> sendMessage() async {
    final text = chatController.text.trim();
    final document = selectedDocument;
    if (text.isEmpty || isProcessing || document == null || apiKey.isEmpty) return;
    chatMessages.add(ChatMessage(text: text, isUser: true));
    chatController.clear();
    isProcessing = true;
    notifyListeners();
    try {
      final answer = await container.chat.ask(
        document: document,
        question: text,
        apiKey: apiKey,
        model: model,
      );
      chatMessages.add(answer);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  void saveProviderSettings(String key, String selectedModel) {
    apiKey = key;
    model = selectedModel;
    notifyListeners();
  }

  @override
  void dispose() {
    searchController.dispose();
    chatController.dispose();
    unawaited(container.dispose());
    super.dispose();
  }
}
