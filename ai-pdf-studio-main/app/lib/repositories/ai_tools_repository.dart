import '../models.dart';
import '../sidecar_client/supervisor.dart';

class AiToolsRepository {
  const AiToolsRepository(this.sidecar);

  final SidecarSupervisor sidecar;

  Future<AiToolResult> generate({
    required String operation,
    required String documentId,
    required String providerId,
    required String model,
    required String apiKey,
    required double temperature,
    required int maxTokens,
    required String consentGrantedAt,
    String text = '',
    String? mode,
    String difficulty = 'medium',
    String language = 'English',
    String tone = 'professional',
    String instruction = '',
    void Function(String)? onJobStarted,
  }) async {
    final started = await sidecar.request('ai.tool.generate', {
      'operation': operation,
      'documentId': documentId,
      'text': text,
      if (mode != null) 'mode': mode,
      'difficulty': difficulty,
      'language': language,
      'tone': tone,
      'instruction': instruction,
      'provider': {
        'id': providerId,
        'model': model,
        'apiKey': apiKey,
        'temperature': temperature,
        'maxTokens': maxTokens,
      },
      'consent': {
        'providerId': providerId,
        'documentId': documentId,
        'scope': 'ai_tools',
        'grantedAt': consentGrantedAt,
      },
    }) as Map<dynamic, dynamic>;
    final jobId = started['jobId'] as String;
    onJobStarted?.call(jobId);
    while (true) {
      final result = await sidecar.request('job.result', {'jobId': jobId}) as Map<dynamic, dynamic>;
      if (result['state'] == 'running') {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      return AiToolResult.fromJson((result['result'] as Map<dynamic, dynamic>? ?? {}));
    }
  }

  Future<String> export({
    required String title,
    required String content,
    required String format,
    required String outputPath,
  }) async {
    final result = await sidecar.request('ai.tool.export', {
      'title': title,
      'content': content,
      'format': format,
      'outputPath': outputPath,
    }) as Map<dynamic, dynamic>;
    return result['path'] as String;
  }
}
