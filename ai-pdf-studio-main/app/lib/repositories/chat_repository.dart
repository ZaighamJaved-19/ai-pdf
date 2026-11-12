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
    String providerId = 'openai',
    double temperature = 0.2,
    int maxTokens = 1200,
    int usageLimit = 0,
    void Function(String)? onDelta,
    void Function(String)? onJobStarted,
  }) async {
    var jobId = '';
    final subscription = sidecar.notifications.listen((event) {
      if (event['method'] != 'chat.delta') return;
      final params = (event['params'] as Map<dynamic, dynamic>? ?? {});
      if (params['jobId'] == jobId) onDelta?.call(params['text'] as String? ?? '');
    });
    try {
      final started = await sidecar.request('chat.ask', {
        'conversationId': document.path,
        'documentId': document.path,
        'question': question,
        'provider': {
          'id': providerId,
          'model': model,
          'apiKey': apiKey,
          'temperature': temperature,
          'maxTokens': maxTokens,
          'usageLimit': usageLimit,
        },
        'consent': {
          'providerId': providerId,
          'documentId': document.path,
          'scope': 'chat',
          'grantedAt': DateTime.now().toUtc().toIso8601String(),
        }
      }) as Map<dynamic, dynamic>;
      jobId = started['jobId'] as String;
      onJobStarted?.call(jobId);
      while (true) {
        final result = await sidecar.request('job.result', {'jobId': jobId}) as Map<dynamic, dynamic>;
        if (result['state'] == 'running') {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        final payload = (result['result'] as Map<dynamic, dynamic>? ?? {});
        final citations = (payload['citations'] as List<dynamic>? ?? const []);
        return ChatMessage(
          id: jobId,
          text: payload['text'] as String? ?? '',
          isUser: false,
          citations: citations.map((item) {
            final citation = item as Map<dynamic, dynamic>;
            return ChatCitation(
              pageNumber: (citation['pageNumber'] as num).toInt(),
              text: citation['text'] as String? ?? '',
            );
          }).toList(),
        );
      }
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> testProvider({required String provider, required String model, required String apiKey}) async {
    await sidecar.request('provider.test', {
      'provider': {'id': provider.toLowerCase(), 'model': model, 'apiKey': apiKey},
    });
  }
}
