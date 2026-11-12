import '../repositories/chat_repository.dart';
import '../repositories/document_repository.dart';
import '../sidecar_client/supervisor.dart';

class AppContainer {
  AppContainer({SidecarSupervisor? sidecar}) : sidecar = sidecar ?? SidecarSupervisor() {
    documents = DocumentRepository(this.sidecar);
    chat = ChatRepository(this.sidecar);
  }

  final SidecarSupervisor sidecar;
  late final DocumentRepository documents;
  late final ChatRepository chat;

  Future<void> start() => sidecar.start();
  Future<void> dispose() => sidecar.stop();
}
