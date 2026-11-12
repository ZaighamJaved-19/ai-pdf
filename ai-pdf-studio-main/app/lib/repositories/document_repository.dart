import '../models.dart';
import '../sidecar_client/supervisor.dart';

class DocumentRepository {
  const DocumentRepository(this.sidecar);

  final SidecarSupervisor sidecar;

  Future<List<PdfDocumentModel>> list({String query = '', bool favorites = false}) async {
    final result = await sidecar.request('library.list', {
      'query': query,
      'scope': favorites ? 'favorites' : 'recent',
      'limit': 100,
    }) as Map<dynamic, dynamic>;
    return ((result['documents'] as List<dynamic>? ?? const [])
        .cast<Map<dynamic, dynamic>>())
        .map(PdfDocumentModel.fromJson)
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
