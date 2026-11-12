import 'package:flutter/material.dart';

import 'models.dart';

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  int navigationIndex = 0;
  PdfDocumentModel? selectedDocument;
  String activeTool = 'Reader';
  bool chatOpen = true;
  bool isProcessing = false;
  String provider = 'OpenAI';
  String model = 'gpt-4o-mini';
  String apiKey = '';
  final searchController = TextEditingController();
  final chatController = TextEditingController();
  final documents = <PdfDocumentModel>[
    const PdfDocumentModel(
      name: 'Q4 Product Strategy.pdf',
      path: 'C:\\Users\\You\\Documents\\Q4 Product Strategy.pdf',
      pages: 24,
      updated: 'Today, 10:42 AM',
      favorite: true,
    ),
    const PdfDocumentModel(
      name: 'Research Notes — AI Retrieval.pdf',
      path: 'C:\\Users\\You\\Documents\\Research Notes — AI Retrieval.pdf',
      pages: 18,
      updated: 'Yesterday',
    ),
    const PdfDocumentModel(
      name: 'Vendor Agreement 2025.pdf',
      path: 'C:\\Projects\\Legal\\Vendor Agreement 2025.pdf',
      pages: 42,
      updated: 'Nov 8, 2026',
    ),
  ];
  final chatMessages = <ChatMessage>[
    const ChatMessage(
      text: 'I’m ready to help you explore this document. Ask about key findings, dates, risks, or action items.',
      isUser: false,
    ),
  ];

  AppState() {
    selectedDocument = documents.first;
  }

  void selectDocument(PdfDocumentModel document) {
    selectedDocument = document;
    navigationIndex = 0;
    notifyListeners();
  }

  void setNavigation(int index) {
    navigationIndex = index;
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

  void toggleFavorite(PdfDocumentModel document) {
    final index = documents.indexOf(document);
    if (index >= 0) {
      documents[index] = document.copyWith(favorite: !document.favorite);
      if (selectedDocument == document) selectedDocument = documents[index];
      notifyListeners();
    }
  }

  void addDocument() {
    final document = PdfDocumentModel(
      name: 'New document.pdf',
      path: 'C:\\Users\\You\\Documents\\New document.pdf',
      pages: 1,
      updated: 'Just now',
    );
    documents.insert(0, document);
    selectedDocument = document;
    notifyListeners();
  }

  void sendMessage() {
    final text = chatController.text.trim();
    if (text.isEmpty || isProcessing) return;
    chatMessages.add(ChatMessage(text: text, isUser: true));
    chatController.clear();
    isProcessing = true;
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      chatMessages.add(
        const ChatMessage(
          text: 'Based on the indexed pages, the strongest themes are launch readiness, customer retention, and reducing operational risk. I found supporting context on page 7.',
          isUser: false,
          citation: 'Source · Page 7',
        ),
      );
      isProcessing = false;
      notifyListeners();
    });
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
    super.dispose();
  }
}
