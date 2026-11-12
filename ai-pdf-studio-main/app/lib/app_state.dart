import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

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
  bool readerFullScreen = false;
  double readerZoom = 1;
  int currentPage = 1;
  bool isProcessing = false;
  bool isLoading = true;
  String? errorMessage;
  String provider = 'OpenAI';
  String model = 'gpt-4o-mini';
  String apiKey = '';
  final searchController = TextEditingController();
  final readerSearchFocusNode = FocusNode();
  final chatController = TextEditingController();
  List<PdfDocumentModel> documents = const [];
  final openDocuments = <PdfDocumentModel>[];
  PdfDocumentModel? get activeTab => selectedDocument;
  final chatMessages = <ChatMessage>[];
  final bookmarks = <int>{};

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
    if (!openDocuments.any((item) => item.path == document.path)) {
      openDocuments.add(document);
    }
    selectedDetails = null;
    navigationIndex = 0;
    errorMessage = null;
    notifyListeners();
    try {
      selectedDetails = await container.documents.open(document);
      currentPage = selectedDetails!.pageCount > 0
          ? document.lastPage.clamp(1, selectedDetails!.pageCount).toInt()
          : 1;
    } catch (error) {
      errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final file = result?.files.single;
    if (file != null && file.path != null) await importDocument(file.path!);
  }

  void closeTab(PdfDocumentModel document) {
    final index = openDocuments.indexWhere((item) => item.path == document.path);
    if (index < 0) return;
    openDocuments.removeAt(index);
    if (selectedDocument?.path == document.path) {
      selectedDocument = openDocuments.isEmpty ? null : openDocuments[index == 0 ? 0 : index - 1];
      selectedDetails = null;
      if (selectedDocument != null) unawaited(selectDocument(selectedDocument!));
    }
    notifyListeners();
  }

  void selectTab(PdfDocumentModel document) {
    unawaited(selectDocument(document));
  }

  void toggleReaderFullScreen() {
    readerFullScreen = !readerFullScreen;
    notifyListeners();
  }

  void zoomBy(double amount) {
    readerZoom = (readerZoom + amount).clamp(.5, 4).toDouble();
    notifyListeners();
  }

  void resetZoom() {
    readerZoom = 1;
    notifyListeners();
  }

  Future<void> printSelected() async {
    final document = selectedDocument;
    if (document == null) return;
    final bytes = await File(document.path).readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> saveLastPage(int pageNumber) async {
    final document = selectedDocument;
    if (document == null || pageNumber < 1 || document.lastPage == pageNumber) return;
    final updated = document.copyWith(lastPage: pageNumber);
    selectedDocument = updated;
    final index = documents.indexWhere((item) => item.path == document.path);
    if (index >= 0) documents[index] = updated;
    final tabIndex = openDocuments.indexWhere((item) => item.path == document.path);
    if (tabIndex >= 0) openDocuments[tabIndex] = updated;
    try {
      await container.sidecar.request('library.upsert', {
        'path': document.path,
        'title': document.name,
        'lastPage': pageNumber,
        'favorite': document.favorite,
      });
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
    readerSearchFocusNode.dispose();
    unawaited(container.dispose());
    super.dispose();
  }
}
