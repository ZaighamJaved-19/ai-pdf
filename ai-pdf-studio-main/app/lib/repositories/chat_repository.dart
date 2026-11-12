import '../models.dart';
import '../sidecar_client/supervisor.dart';

class ChatRepository {
  const ChatRepository(this.sidecar);

  final SidecarSupervisor sidecar;

  Future<ChatMessage> ask({
    required PdfDocumentModel document,
    required String question,
    required String apiKey,
    required String model,
  }) async {
    final started = await sidecar.request('chat.ask', {
      'conversationId': document.path,
      'documentId': document.path,
      'question': question,
      'provider': {'id': 'openai', 'model': model, 'apiKey': apiKey},
      'consent': {
        'providerId': 'openai',
        'documentId': document.path,
        'scope': 'chat',
        'grantedAt': DateTime.now().toUtc().toIso8601String(),
      },
    }) as Map<dynamic, dynamic>;
    final jobId = started['jobId'] as String;
    while (true) {
      final result = await sidecar.request('job.result', {'jobId': jobId}) as Map<dynamic, dynamic>;
      if (result['state'] == 'running') {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      final payload = (result['result'] as Map<dynamic, dynamic>? ?? {});
      final citations = (payload['citations'] as List<dynamic>? ?? const []);
      final citation = citations.isEmpty ? null : 'Source · Page ${(citations.first as Map)['pageNumber']}';
      return ChatMessage(text: payload['text'] as String? ?? '', isUser: false, citation: citation);
    }
  }
}
