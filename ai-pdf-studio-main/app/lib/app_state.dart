import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'di/container.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  AppState(this.container) {
    _initialize();
  }

  final AppContainer container;
  ThemeMode themeMode = ThemeMode.system;
  int navigationIndex = 0;
  String? selectedFolder;
  String? selectedTag;
  String? selectedWorkspace;
  PdfDocumentModel? selectedDocument;
  PdfDocumentDetails? selectedDetails;
  String activeTool = 'Reader';
  bool chatOpen = true;
  double leftSidebarWidth = 224;
  double aiPanelWidth = 330;
  bool leftSidebarCollapsed = false;
  String workspaceMode = 'Reading';
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
  bool onboardingCompleted = false;
  String? infoPage;
  double defaultZoom = 1;
  String openingBehavior = 'Restore last page';
  String language = 'English';
  String exportFormat = 'PDF';
  String downloadFolder = '';
  bool cacheEnabled = true;
  int recentDocumentLimit = 20;
  bool contentSearchMode = false;
  List<ContentMatch> contentMatches = const [];
  List<String> folders = const [];
  List<String> tags = const [];
  List<LibraryWorkspace> workspaces = const [];
  SharedPreferences? _preferences;

  Future<void> _initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      _loadPreferences();
      await container.start();
      await refreshLibraryFacets();
      await refreshDocuments();
    } catch (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  void _loadPreferences() {
      final preferences = _preferences;
      if (preferences == null) return;
      final theme = preferences.getString('themeMode');
      themeMode = ThemeMode.values.firstWhere(
        (value) => value.name == theme,
        orElse: () => ThemeMode.system,
      );
      onboardingCompleted = preferences.getBool('onboardingCompleted') ?? false;
      leftSidebarWidth = preferences.getDouble('leftSidebarWidth') ?? 224;
      aiPanelWidth = preferences.getDouble('aiPanelWidth') ?? 330;
      leftSidebarCollapsed = preferences.getBool('leftSidebarCollapsed') ?? false;
      defaultZoom = preferences.getDouble('defaultZoom') ?? 1;
      readerZoom = defaultZoom;
      openingBehavior = preferences.getString('openingBehavior') ?? 'Restore last page';
      language = preferences.getString('language') ?? 'English';
      exportFormat = preferences.getString('exportFormat') ?? 'PDF';
      downloadFolder = preferences.getString('downloadFolder') ?? '';
      cacheEnabled = preferences.getBool('cacheEnabled') ?? true;
      recentDocumentLimit = preferences.getInt('recentDocumentLimit') ?? 20;
    }

  Future<void> _savePreference(String key, Object value) async {
      final preferences = _preferences;
      if (preferences == null) return;
      if (value is bool) await preferences.setBool(key, value);
      if (value is double) await preferences.setDouble(key, value);
      if (value is int) await preferences.setInt(key, value);
      if (value is String) await preferences.setString(key, value);
    }

  void setThemeMode(ThemeMode value) {
      themeMode = value;
      unawaited(_savePreference('themeMode', value.name));
      notifyListeners();
    }

  void completeOnboarding() {
      onboardingCompleted = true;
      unawaited(_savePreference('onboardingCompleted', true));
      notifyListeners();
    }

  void setSidebarWidth(double value) {
      leftSidebarWidth = value.clamp(180, 360).toDouble();
      unawaited(_savePreference('leftSidebarWidth', leftSidebarWidth));
      notifyListeners();
    }

  void setAiPanelWidth(double value) {
      aiPanelWidth = value.clamp(280, 520).toDouble();
      unawaited(_savePreference('aiPanelWidth', aiPanelWidth));
      notifyListeners();
    }

  void toggleSidebar() {
      leftSidebarCollapsed = !leftSidebarCollapsed;
      unawaited(_savePreference('leftSidebarCollapsed', leftSidebarCollapsed));
      notifyListeners();
    }

  void setWorkspaceMode(String value) {
      workspaceMode = value;
      if (value == 'AI') chatOpen = true;
      notifyListeners();
    }

  void setDefaultZoom(double value) {
      defaultZoom = value;
      readerZoom = value;
      unawaited(_savePreference('defaultZoom', value));
      notifyListeners();
    }

  void setOpeningBehavior(String value) {
      openingBehavior = value;
      unawaited(_savePreference('openingBehavior', value));
      notifyListeners();
    }

  void setLanguage(String value) {
      language = value;
      unawaited(_savePreference('language', value));
      notifyListeners();
    }

  void setExportFormat(String value) {
      exportFormat = value;
      unawaited(_savePreference('exportFormat', value));
      notifyListeners();
    }

  void setDownloadFolder(String value) {
      downloadFolder = value;
      unawaited(_savePreference('downloadFolder', value));
      notifyListeners();
    }

  void setCacheEnabled(bool value) {
      cacheEnabled = value;
      unawaited(_savePreference('cacheEnabled', value));
      notifyListeners();
    }

  void setRecentDocumentLimit(int value) {
      recentDocumentLimit = value;
      unawaited(_savePreference('recentDocumentLimit', value));
      notifyListeners();
    }

  void openInfoPage(String page) {
      infoPage = page;
      notifyListeners();
    }

  void closeInfoPage() {
      infoPage = null;
      notifyListeners();
  }

  Future<void> refreshDocuments() async {
    isLoading = true;
    notifyListeners();
    try {
      documents = await container.documents.list(
        query: searchController.text.trim(),
        favorites: navigationIndex == 2,
        folder: navigationIndex == 3 ? selectedFolder : null,
        tag: navigationIndex == 5 ? selectedTag : null,
        workspace: navigationIndex == 4 ? selectedWorkspace : null,
      );
      if (recentDocumentLimit > 0 && navigationIndex == 1 && documents.length > recentDocumentLimit) {
        documents = documents.take(recentDocumentLimit).toList();
      }

      isLoading = false;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshLibraryFacets() async {
    try {
      folders = await container.documents.folders();
      workspaces = await container.documents.workspaces();
      final all = await container.documents.list();
      tags = all.expand((document) => document.tags).toSet().toList()..sort();
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> submitSearch() async {
    if (contentSearchMode) {
      try {
        contentMatches = await container.documents.searchContent(searchController.text.trim());
        notifyListeners();
      } catch (error) {
        errorMessage = error.toString();
        notifyListeners();
      }
    } else {
      await refreshDocuments();
    }
  }

  Future<void> openSearchMatch(ContentMatch match) async {
    final matching = documents.where((document) => document.path == match.path);
    final existing = matching.isEmpty ? null : matching.first;
    if (existing != null) {
      await selectDocument(existing);
      return;
    }
    final matches = await container.documents.list(query: match.path);
    if (matches.isNotEmpty) await selectDocument(matches.first);
  }

  void toggleContentSearch() {
    contentSearchMode = !contentSearchMode;
    contentMatches = const [];
    notifyListeners();
  }

  Future<void> selectFolder(String? folder) async {
    selectedFolder = folder;
    navigationIndex = 3;
    await refreshDocuments();
  }

  Future<void> selectWorkspace(String? workspace) async {
    selectedWorkspace = workspace;
    navigationIndex = 4;
    await refreshDocuments();
  }

  Future<void> selectTag(String? tag) async {
    selectedTag = tag;
    navigationIndex = 5;
    await refreshDocuments();
  }

  Future<void> removeFromLibrary(PdfDocumentModel document) async {
    try {
      await container.documents.remove(document);
      openDocuments.removeWhere((item) => item.path == document.path);
      if (selectedDocument?.path == document.path) {
        selectedDocument = null;
        selectedDetails = null;
      }
      await refreshLibraryFacets();
      await refreshDocuments();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> relocateDocument(PdfDocumentModel document, String newPath) async {
    try {
      final updated = await container.documents.relocate(document, newPath);
      final index = documents.indexWhere((item) => item.path == document.path);
      if (index >= 0) documents[index] = updated;
      if (selectedDocument?.path == document.path) selectedDocument = updated;
      await refreshLibraryFacets();
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> saveNote(PdfDocumentModel document, String note) async {
    try {
      final saved = await container.documents.saveNote(document, note);
      _replaceDocument(document.copyWith(note: saved));
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> saveTags(PdfDocumentModel document, List<String> tags) async {
    try {
      final saved = await container.documents.setTags(document, tags);
      _replaceDocument(document.copyWith(tags: saved));
      await refreshLibraryFacets();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  void _replaceDocument(PdfDocumentModel updated) {
    final index = documents.indexWhere((item) => item.path == updated.path);
    if (index >= 0) documents[index] = updated;
    final tabIndex = openDocuments.indexWhere((item) => item.path == updated.path);
    if (tabIndex >= 0) openDocuments[tabIndex] = updated;
    if (selectedDocument?.path == updated.path) selectedDocument = updated;
    notifyListeners();
  }

  Future<void> createWorkspace(String name) async {
    try {
      await container.documents.createWorkspace(name);
      await refreshLibraryFacets();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> addToWorkspace(String workspace, PdfDocumentModel document) async {
    try {
      await container.documents.addToWorkspace(workspace, document);
      selectedWorkspace = workspace;
      navigationIndex = 4;
      await refreshDocuments();
    } catch (error) {
      errorMessage = error.toString();
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
          ? (openingBehavior == 'Start from first page'
              ? 1
              : document.lastPage.clamp(1, selectedDetails!.pageCount).toInt())
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
    if (index == 3) selectedFolder = null;
    if (index == 4) selectedWorkspace = null;
    if (index == 5) selectedTag = null;
    if (index == 0 || index == 1 || index == 2 || index == 3 || index == 4 || index == 5) {
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
    setThemeMode(themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
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
