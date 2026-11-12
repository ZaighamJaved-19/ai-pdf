import '../models.dart';
import '../sidecar_client/supervisor.dart';

class DocumentRepository {
  const DocumentRepository(this.sidecar);

  final SidecarSupervisor sidecar;

  Future<List<PdfDocumentModel>> list({
    String query = '',
    bool favorites = false,
    String? folder,
    String? tag,
    String? workspace,
  }) async {
    final result = await sidecar.request('library.list', {
      'query': query,
      'scope': favorites ? 'favorites' : 'recent',
      'limit': 100,
      if (folder != null) 'folder': folder,
      if (tag != null) 'tag': tag,
      if (workspace != null) 'workspace': workspace,
    }) as Map<dynamic, dynamic>;
    return ((result['documents'] as List<dynamic>? ?? const [])
        .cast<Map<dynamic, dynamic>>())
        .map(PdfDocumentModel.fromJson)
        .toList();
  }

  Future<void> remove(PdfDocumentModel document) async {
    await sidecar.request('library.remove', {'path': document.path});
  }

  Future<PdfDocumentModel> relocate(PdfDocumentModel document, String newPath) async {
    final result = await sidecar.request('library.relocate', {'oldPath': document.path, 'newPath': newPath}) as Map<dynamic, dynamic>;
    return PdfDocumentModel.fromJson(result);
  }

  Future<String> saveNote(PdfDocumentModel document, String note) async {
    final result = await sidecar.request('library.note.set', {'path': document.path, 'note': note}) as Map<dynamic, dynamic>;
    return result['note'] as String? ?? '';
  }

  Future<List<String>> setTags(PdfDocumentModel document, List<String> tags) async {
    final result = await sidecar.request('library.tags.set', {'path': document.path, 'tags': tags}) as Map<dynamic, dynamic>;
    return (result['tags'] as List<dynamic>? ?? const []).cast<String>();
  }

  Future<List<String>> folders() async {
    final result = await sidecar.request('library.folders', {}) as Map<dynamic, dynamic>;
    return (result['folders'] as List<dynamic>? ?? const []).cast<String>();
  }

  Future<List<LibraryWorkspace>> workspaces() async {
    final result = await sidecar.request('library.workspaces', {}) as Map<dynamic, dynamic>;
    return (result['workspaces'] as List<dynamic>? ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map((item) => LibraryWorkspace(name: item['name'] as String, createdAt: item['createdAt'] as String))
        .toList();
  }

  Future<LibraryWorkspace> createWorkspace(String name) async {
    final result = await sidecar.request('library.workspace.create', {'name': name}) as Map<dynamic, dynamic>;
    return LibraryWorkspace(name: result['name'] as String, createdAt: result['createdAt'] as String);
  }

  Future<void> addToWorkspace(String workspace, PdfDocumentModel document) async {
    await sidecar.request('library.workspace.add', {'workspace': workspace, 'path': document.path});
  }

  Future<List<ContentMatch>> searchContent(String query) async {
    final result = await sidecar.request('library.searchContent', {'query': query, 'limit': 100}) as Map<dynamic, dynamic>;
    return (result['matches'] as List<dynamic>? ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map((item) => ContentMatch(
              path: item['path'] as String,
              pageNumber: int.parse(item['page_number'].toString()),
              snippet: item['snippet'] as String? ?? '',
            ))
        .toList();
  }

  Future<PdfDocumentModel> upsert(String path) async {
    final result = await sidecar.request('library.upsert', {'path': path}) as Map<dynamic, dynamic>;
    return PdfDocumentModel.fromJson(result);
  }

  Future<PdfDocumentDetails> open(PdfDocumentModel document) async {
    final inspection = await sidecar.request('pdf.inspect', {'path': document.path}) as Map<dynamic, dynamic>;
    final extracted = await sidecar.request('pdf.extractText', {'path': document.path}) as Map<dynamic, dynamic>;
    return PdfDocumentDetails.fromJson(inspection, extracted);
  }
}
