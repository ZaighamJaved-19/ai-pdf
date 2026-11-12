import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'di/container.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  AppState(this.container) {
    _initialize();
  }

  String _nextEditedPath(String label) {
    final document = selectedDocument!;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '${document.path.substring(0, document.path.length - 4)}.$label-$stamp.pdf';
  }

  Future<String?> applyPdfEdit({
    List<Map<String, dynamic>> annotations = const [],
    List<Map<String, dynamic>> text = const [],
    List<Map<String, dynamic>> images = const [],
    Map<String, double>? crop,
    String? header,
    String? footer,
    String? watermark,
    String? outputPath,
    String label = 'edited',
  }) async {
    final input = readerPdfPath;
    if (input == null) return null;
    try {
      final output = outputPath ?? _nextEditedPath(label);
      final path = await container.pdfEditor.edit(
        inputPath: input,
        outputPath: output,
        annotations: annotations,
        text: text,
        images: images,
        crop: crop,
        header: header,
        footer: footer,
        watermark: watermark,
      );
      _recordEdit(path);
      return path;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> extractPdfPages(List<int> pages, {String? outputPath}) async {
    final input = readerPdfPath;
    if (input == null || pages.isEmpty) return null;
    try {
      final path = await container.pdfEditor.extractPages(
        inputPath: input,
        outputPath: outputPath ?? _nextEditedPath('pages'),
        pages: pages,
      );
      _recordEdit(path);
      return path;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> transformPdf({
    List<int>? order,
    Map<int, int> rotate = const {},
    List<int> delete = const [],
    List<int> duplicate = const [],
    List<int> blankAfter = const [],
  }) async {
    final input = readerPdfPath;
    if (input == null) return null;
    try {
      final path = await container.pdfEditor.transform(
        inputPath: input,
        outputPath: _nextEditedPath('pages'),
        order: order,
        rotate: rotate,
        delete: delete,
        duplicate: duplicate,
        blankAfter: blankAfter,
      );
      _recordEdit(path);
      return path;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  void _recordEdit(String path) {
    if (_editCursor + 1 < _editHistory.length) {
      _editHistory.removeRange(_editCursor + 1, _editHistory.length);
    }
    _editHistory.add(path);
    _editCursor = _editHistory.length - 1;
    editedPdfPath = path;
    notifyListeners();
  }

  void undoPdfEdit() {
    if (!canUndoEdit) return;
    _editCursor--;
    editedPdfPath = _editCursor < 0 ? null : _editHistory[_editCursor];
    notifyListeners();
  }

  void redoPdfEdit() {
    if (!canRedoEdit) return;
    _editCursor++;
    editedPdfPath = _editHistory[_editCursor];
    notifyListeners();
  }

  Future<String?> savePdfAs() async {
    final input = readerPdfPath;
    if (input == null) return null;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save edited PDF as',
      fileName: '${selectedDocument!.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '')} - edited.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null) return null;
    try {
      final saved = await container.pdfEditor.edit(inputPath: input, outputPath: path);
      _recordEdit(saved);
      return saved;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> savePdf() async {
    if (editedPdfPath == null) return savePdfAs();
    return editedPdfPath;
  }

  Future<String?> compressCurrentPdf(String outputPath) async {
    final input = readerPdfPath;
    if (input == null) return null;
    try {
      final path = await container.pdfEditor.compress(input, outputPath);
      _recordEdit(path);
      return path;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return null;
    }

    Future<String?> protectCurrentPdf(String password, String outputPath, {List<String> permissions = const []}) async {
      final input = readerPdfPath;
      if (input == null || password.isEmpty) return null;
      try {
        final path = await container.pdfEditor.protect(
          inputPath: input,
          outputPath: outputPath,
          userPassword: password,
          permissions: permissions,
        );
        _recordEdit(path);
        return path;
      } catch (error) {
        errorMessage = error.toString();
        notifyListeners();
        return null;
      }
    }

    Future<String?> removePasswordFromCurrentPdf(String password, String outputPath) async {
      final input = readerPdfPath;
      if (input == null || password.isEmpty) return null;
      try {
        final path = await container.pdfEditor.removePassword(input, outputPath, password);
        _recordEdit(path);
        return path;
      } catch (error) {
        errorMessage = error.toString();
        notifyListeners();
        return null;
      }
    }

    Future<String?> removeMetadataFromCurrentPdf(String outputPath) async {
      final input = readerPdfPath;
      if (input == null) return null;
      try {
        final path = await container.pdfEditor.removeMetadata(input, outputPath);
        _recordEdit(path);
        return path;
      } catch (error) {
        errorMessage = error.toString();
        notifyListeners();
        return null;
      }
    }

    Future<String?> redactCurrentPdf(String outputPath, {List<String> terms = const [], List<Map<String, dynamic>> regions = const []}) async {
      final input = readerPdfPath;
      if (input == null) return null;
      try {
        final path = await container.pdfEditor.redact(inputPath: input, outputPath: outputPath, terms: terms, regions: regions);
        _recordEdit(path);
        return path;
      } catch (error) {
        errorMessage = error.toString();
        notifyListeners();
        return null;
      }
    }
  }

  Future<String?> mergePdfFiles(List<String> inputPaths, String outputPath) async {
    if (inputPaths.isEmpty) return null;
    try {
      final path = await container.pdfEditor.merge(inputPaths, outputPath);
      _recordEdit(path);
      return path;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<List<String>> splitCurrentPdf(String outputDirectory) async {
    final input = readerPdfPath;
    if (input == null) return const [];
    try {
      return await container.pdfEditor.split(input, outputDirectory);
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
      return const [];
    }
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
  double temperature = 0.2;
  int maxTokens = 1200;
  int usageLimit = 0;
  bool isTestingProvider = false;
  String? providerStatus;
  bool isOnline = false;
  final searchController = TextEditingController();
  final readerSearchFocusNode = FocusNode();
  final chatController = TextEditingController();
  List<PdfDocumentModel> documents = const [];
  final openDocuments = <PdfDocumentModel>[];
  PdfDocumentModel? get activeTab => selectedDocument;
  String? get readerPdfPath => selectedDocument == null ? null : editedPdfPath ?? selectedDocument!.path;
  bool get canUndoEdit => _editCursor >= 0;
  bool get canRedoEdit => _editCursor + 1 < _editHistory.length;
  final chatMessages = <ChatMessage>[];
  final conversations = <ChatConversation>[];
  String? activeConversationId;
  String streamingResponse = '';
  String? activeChatJobId;
  final consentedDocuments = <String>{};
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
  String? indexingJobId;
  String? indexingStage;
  double? indexingProgress;
  AiToolResult? aiToolResult;
  String? activeAiToolJobId;
  bool aiToolProcessing = false;
  String? editedPdfPath;
  final _editHistory = <String>[];
  int _editCursor = -1;
  bool contentSearchMode = false;
  List<ContentMatch> contentMatches = const [];
  List<String> folders = const [];
  List<String> tags = const [];
  List<LibraryWorkspace> workspaces = const [];
  SharedPreferences? _preferences;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  static const _secureStorage = FlutterSecureStorage();

  Future<void> _initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      _loadPreferences();
      _loadConversations();
      apiKey = await _secureStorage.read(key: 'aips_${provider.toLowerCase()}_api_key') ?? '';
      await container.start();
      _notificationSubscription = container.sidecar.notifications.listen(_handleNotification);
      await refreshLibraryFacets();
      await refreshDocuments();
    } catch (error) {
      errorMessage = error.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  void _handleNotification(Map<String, dynamic> event) {
    if (event['method'] != 'job.progress') return;
    final params = (event['params'] as Map<dynamic, dynamic>? ?? {});
    if (params['jobId'] != indexingJobId) return;
    indexingStage = params['stage'] as String?;
    indexingProgress = (params['fraction'] as num?)?.toDouble();
    if (indexingStage == 'complete') {
      indexingJobId = null;
    }
    notifyListeners();
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

    void _loadConversations() {
      final raw = _preferences?.getString('chatConversations');
      if (raw == null || raw.isEmpty) return;
      try {
        final items = jsonDecode(raw) as List<dynamic>;
        conversations
          ..clear()
          ..addAll(items.cast<Map<dynamic, dynamic>>().map((item) => ChatConversation(
                id: item['id'] as String,
                title: item['title'] as String,
                documentPath: item['documentPath'] as String,
                messages: (item['messages'] as List<dynamic>? ?? const []).map((message) {
                  final citations = (message['citations'] as List<dynamic>? ?? const [])
                      .cast<Map<dynamic, dynamic>>()
                      .map((citation) => ChatCitation(
                            pageNumber: (citation['pageNumber'] as num).toInt(),
                            text: citation['text'] as String? ?? '',
                          ))
                      .toList();
                  return ChatMessage(
                    id: message['id'] as String? ?? '',
                    text: message['text'] as String? ?? '',
                    isUser: message['isUser'] as bool? ?? false,
                    citations: citations,
                  );
                }).toList(),
              )));
      } catch (_) {
        conversations.clear();
      }
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

    void setProvider(String value) {
      provider = value;
      model = value == 'Anthropic' ? 'claude-3-5-sonnet-latest' : 'gpt-4o-mini';
      unawaited(_loadProviderKey());
      notifyListeners();
    }

    Future<void> _loadProviderKey() async {
      apiKey = await _secureStorage.read(key: 'aips_${provider.toLowerCase()}_api_key') ?? '';
      notifyListeners();
    }

    void setModel(String value) {
      model = value;
      notifyListeners();
    }

    void setTemperature(double value) {
      temperature = value;
      notifyListeners();
    }

    void setMaxTokens(int value) {
      maxTokens = value;
      notifyListeners();
    }

    void setUsageLimit(int value) {
      usageLimit = value;
      notifyListeners();
    }

    Future<void> saveProviderSettings(String key, String selectedModel) async {
      apiKey = key;
      model = selectedModel;
      await _secureStorage.write(key: 'aips_${provider.toLowerCase()}_api_key', value: key);
      notifyListeners();
    }

    Future<void> testProviderConnection() async {
      if (apiKey.isEmpty) {
        providerStatus = 'Enter an API key first.';
        notifyListeners();
        return;
      }
      isTestingProvider = true;
      providerStatus = null;
      notifyListeners();
      try {
        await container.chat.testProvider(
          provider: provider,
          model: model,
          apiKey: apiKey,
        );
        providerStatus = 'Connection successful.';
        isOnline = true;
      } catch (error) {
        providerStatus = error.toString();
        isOnline = false;
      } finally {
        isTestingProvider = false;
        notifyListeners();
      }
    }

    bool hasConsentForSelectedDocument() =>
        selectedDocument != null &&
        consentedDocuments.contains('${provider.toLowerCase()}:${selectedDocument!.path}');

    void grantConsentForSelectedDocument() {
        if (selectedDocument != null) {
          consentedDocuments.add('${provider.toLowerCase()}:${selectedDocument!.path}');
        }
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
    editedPdfPath = null;
    _editHistory.clear();
    _editCursor = -1;
    if (!openDocuments.any((item) => item.path == document.path)) {
      openDocuments.add(document);
    }
    selectedDetails = null;
    newConversation();
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
      await _startIndexing(document.path);
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> _startIndexing(String path) async {
    try {
      final result = await container.sidecar.request('index.start', {
        'path': path,
        'provider': {
          'id': provider.toLowerCase(),
          'apiKey': apiKey,
        },
      }) as Map<dynamic, dynamic>;
      indexingJobId = result['jobId'] as String?;
      indexingStage = 'queued';
      indexingProgress = 0;
      notifyListeners();
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
    if (text.isEmpty || isProcessing || document == null || apiKey.isEmpty || !hasConsentForSelectedDocument()) return;
    chatMessages.add(ChatMessage(text: text, isUser: true));
    chatController.clear();
    isProcessing = true;
    streamingResponse = '';
    notifyListeners();
    try {
      final answer = await container.chat.ask(
        document: document,
        question: text,
        apiKey: apiKey,
        model: model,
        providerId: provider.toLowerCase(),
        temperature: temperature,
        maxTokens: maxTokens,
        usageLimit: usageLimit,
        onJobStarted: (jobId) {
          activeChatJobId = jobId;
          notifyListeners();
        },
        onDelta: (delta) {
          streamingResponse += delta;
          notifyListeners();
        },
      );
      chatMessages.add(answer);
      streamingResponse = '';
      activeChatJobId = null;
      _saveConversation();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isProcessing = false;
      activeChatJobId = null;
      notifyListeners();
    }

    Future<void> generateAiTool({
      required String operation,
      String text = '',
      String? mode,
      String difficulty = 'medium',
      String language = 'English',
      String tone = 'professional',
      String instruction = '',
    }) async {
      final document = selectedDocument;
      if (document == null || !hasConsentForSelectedDocument()) return;
      if (apiKey.isEmpty) {
        errorMessage = 'Add a provider API key in Settings before generating a result.';
        notifyListeners();
        return;
      }
      aiToolProcessing = true;
      errorMessage = null;
      notifyListeners();
      try {
        aiToolResult = await container.aiTools.generate(
          operation: operation,
          documentId: document.path,
          providerId: provider.toLowerCase(),
          model: model,
          apiKey: apiKey,
          temperature: temperature,
          maxTokens: maxTokens,
          consentGrantedAt: DateTime.now().toUtc().toIso8601String(),
          text: text,
          mode: mode,
          difficulty: difficulty,
          language: language,
          tone: tone,
          instruction: instruction,
          onJobStarted: (jobId) {
            activeAiToolJobId = jobId;
            notifyListeners();
          },
        );
      } catch (error) {
        errorMessage = error.toString();
      } finally {
        aiToolProcessing = false;
        activeAiToolJobId = null;
        notifyListeners();
      }
    }

    Future<String?> exportAiToolResult(String format) async {
      final result = aiToolResult;
      if (result == null) return null;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export AI result',
        fileName: '${result.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')}.$format',
        type: FileType.custom,
        allowedExtensions: [format],
      );
      if (path == null) return null;
      return container.aiTools.export(
        title: result.title,
        content: result.content,
        format: format,
        outputPath: path,
      );
    }
  }

  Future<void> stopChat() async {
    final jobId = activeChatJobId;
    if (jobId != null) await container.sidecar.cancel(jobId);
    isProcessing = false;
    activeChatJobId = null;
    streamingResponse = '';
    notifyListeners();
  }

  void newConversation() {
    chatMessages.clear();
    streamingResponse = '';
    activeConversationId = DateTime.now().microsecondsSinceEpoch.toString();
    if (selectedDocument != null) {
      conversations.add(ChatConversation(
        id: activeConversationId!,
        title: 'New conversation',
        documentPath: selectedDocument!.path,
      ));
    }
    notifyListeners();
  }

  void openConversation(ChatConversation conversation) {
    activeConversationId = conversation.id;
    chatMessages
      ..clear()
      ..addAll(conversation.messages);
    streamingResponse = '';
    notifyListeners();
  }

  void clearChat() {
    chatMessages.clear();
    streamingResponse = '';
    _saveConversation();
    notifyListeners();
  }

  Future<void> deleteAllChatHistory() async {
    conversations.clear();
    chatMessages.clear();
    streamingResponse = '';
    activeConversationId = null;
    await _preferences?.remove('chatConversations');
    notifyListeners();
  }

  Future<void> deleteCache() async {
    try {
      await container.sidecar.request('privacy.clearCache', const {});
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<String?> exportUserData() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export AI PDF Studio data',
      fileName: 'ai-pdf-studio-data.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return null;
    final payload = {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'documents': documents.map((document) => {
        'path': document.path,
        'name': document.name,
        'favorite': document.favorite,
        'note': document.note,
        'tags': document.tags,
      }).toList(),
      'conversations': conversations.map((conversation) => {
        'id': conversation.id,
        'title': conversation.title,
        'documentPath': conversation.documentPath,
        'messages': conversation.messages.map((message) => {'isUser': message.isUser, 'text': message.text, 'citation': message.citation}).toList(),
      }).toList(),
      'settings': {'provider': provider, 'model': model, 'theme': themeMode.name},
    };
    await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return path;
  }

  void renameConversation(String id, String title) {
    for (final conversation in conversations) {
      if (conversation.id == id) conversation.title = title;
    }
    _persistConversations();
    notifyListeners();
  }

  void deleteConversation(String id) {
    conversations.removeWhere((conversation) => conversation.id == id);
    if (activeConversationId == id) newConversation();
    _persistConversations();
    notifyListeners();
  }

  void regenerateLast() {
    if (isProcessing || chatMessages.isEmpty) return;
    final lastUser = chatMessages.lastWhere(
      (message) => message.isUser,
      orElse: () => const ChatMessage(text: '', isUser: true),
    );
    if (lastUser.text.isEmpty) return;
    chatMessages.removeWhere((message) => !message.isUser);
    chatController.text = lastUser.text;
    unawaited(sendMessage());
  }

  void _saveConversation() {
    final id = activeConversationId;
    if (id == null) return;
    for (final conversation in conversations) {
      if (conversation.id == id) {
        conversation.messages
          ..clear()
          ..addAll(chatMessages);
        if (conversation.title == 'New conversation' && chatMessages.isNotEmpty) {
          conversation.title = chatMessages.first.text;
        }
      }
    }
    _persistConversations();

    notifyListeners();
  }

  void _persistConversations() {
    final value = conversations
        .map((conversation) => {
              'id': conversation.id,
              'title': conversation.title,
              'documentPath': conversation.documentPath,
              'messages': conversation.messages
                  .map((message) => {
                        'id': message.id,
                        'text': message.text,
                        'isUser': message.isUser,
                        'citations': message.citations
                            .map((citation) => {
                                  'pageNumber': citation.pageNumber,
                                  'text': citation.text,
                                })
                            .toList(),
                      })
                  .toList(),
            })
        .toList();
    unawaited(_savePreference('chatConversations', jsonEncode(value)));
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    searchController.dispose();
    chatController.dispose();
    readerSearchFocusNode.dispose();
    unawaited(container.dispose());
    super.dispose();
  }
}
