import '../repositories/chat_repository.dart';
import '../repositories/document_repository.dart';
import '../repositories/ai_tools_repository.dart';
import '../repositories/pdf_editor_repository.dart';
import '../sidecar_client/supervisor.dart';

class AppContainer {
  AppContainer({SidecarSupervisor? sidecar}) : sidecar = sidecar ?? SidecarSupervisor() {
    documents = DocumentRepository(this.sidecar);
    chat = ChatRepository(this.sidecar);
    aiTools = AiToolsRepository(this.sidecar);
    pdfEditor = PdfEditorRepository(this.sidecar);
  }

  final SidecarSupervisor sidecar;
  late final DocumentRepository documents;
  late final ChatRepository chat;
  late final AiToolsRepository aiTools;
  late final PdfEditorRepository pdfEditor;

  Future<void> start() => sidecar.start();
  Future<void> dispose() => sidecar.stop();
}
