import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../app_state.dart';
import '../widgets/common.dart';

class AiToolsPage extends StatefulWidget {
  const AiToolsPage({required this.state, super.key});

  final AppState state;

  @override
  State<AiToolsPage> createState() => _AiToolsPageState();
}

class _AiToolsPageState extends State<AiToolsPage> {
  final textController = TextEditingController();
  String summaryMode = 'brief';
  String difficulty = 'medium';
  String language = 'Spanish';
  String writingMode = 'rewrite';
  String tone = 'professional';

  AppState get state => widget.state;

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = state.aiToolResult;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text('AI tools', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text('Generate a separate result from the selected document. Your original PDF is never overwritten.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 22),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(state.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (state.selectedDocument == null)
          const SurfaceCard(
            child: ListTile(
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text('Open a document first'),
              subtitle: Text('Choose a PDF from the library to use AI tools.'),
            ),
          )
        else ...[
          _sourceField(context),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _toolCard(context, 'Summarize', Icons.summarize_outlined, _summaryDialog),
              _toolCard(context, 'Generate notes', Icons.sticky_note_2_outlined, () => _run(operation: 'notes')),
              _toolCard(context, 'Quiz', Icons.quiz_outlined, () => _difficultyDialog('quiz')),
              _toolCard(context, 'Flashcards', Icons.style_outlined, () => _difficultyDialog('flashcards')),
              _toolCard(context, 'Translate', Icons.translate, _translationDialog),
              _toolCard(context, 'Writing assistant', Icons.edit_note_outlined, _writingDialog),
            ],
          ),
        ],
        if (state.aiToolProcessing) ...[
          const SizedBox(height: 22),
          const LinearProgressIndicator(),
        ],
        if (result != null) ...[
          const SizedBox(height: 24),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(result.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
                    PopupMenuButton<String>(
                      tooltip: 'Export',
                      onSelected: (format) => state.exportAiToolResult(format),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'txt', child: Text('Export TXT')),
                        PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                        PopupMenuItem(value: 'docx', child: Text('Export DOCX')),
                      ],
                      child: const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
                const Divider(height: 24),
                MarkdownBody(data: result.content, selectable: true),
                if (result.items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...result.items.asMap().entries.map((entry) => _itemCard(entry.key + 1, entry.value)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sourceField(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Source', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('Leave this empty to use the full document. Paste selected text for a focused operation.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: textController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Selected text (optional)', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _toolCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 220,
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: state.aiToolProcessing ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 11),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _summaryDialog() async {
    final accepted = await _choose<bool>(
      'Summary style',
      DropdownButtonFormField<String>(
        value: summaryMode,
        items: const [
          DropdownMenuItem(value: 'brief', child: Text('Brief')),
          DropdownMenuItem(value: 'executive', child: Text('Executive')),
          DropdownMenuItem(value: 'detailed', child: Text('Detailed')),
          DropdownMenuItem(value: 'bullet', child: Text('Bullet points')),
          DropdownMenuItem(value: 'outline', child: Text('Outline')),
          DropdownMenuItem(value: 'academic', child: Text('Academic')),
          DropdownMenuItem(value: 'action_items', child: Text('Action items')),
          DropdownMenuItem(value: 'one_sentence', child: Text('One sentence')),
        ],
        onChanged: (value) => summaryMode = value ?? summaryMode,
      ),
    );
    if (accepted != null) await _run(operation: 'summary', mode: summaryMode);
  }

  Future<void> _translationDialog() async {
    final accepted = await _choose<bool>(
      'Translate document or selected text',
      DropdownButtonFormField<String>(
        value: language,
        items: const ['English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese', 'Arabic']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => language = value ?? language,
      ),
    );
    if (accepted != null) await _run(operation: 'translate', language: language);
  }

  Future<void> _difficultyDialog(String operation) async {
    final accepted = await _choose<bool>(
      operation == 'quiz' ? 'Quiz difficulty' : 'Flashcard difficulty',
      DropdownButtonFormField<String>(
        value: difficulty,
        items: const [
          DropdownMenuItem(value: 'easy', child: Text('Easy')),
          DropdownMenuItem(value: 'medium', child: Text('Medium')),
          DropdownMenuItem(value: 'hard', child: Text('Hard')),
        ],
        onChanged: (value) => difficulty = value ?? difficulty,
      ),
    );
    if (accepted != null) await _run(operation: operation, difficulty: difficulty);
  }

  Future<void> _writingDialog() async {
    final accepted = await _choose<bool>(
      'Writing assistant',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: writingMode,
            items: const [
              DropdownMenuItem(value: 'rewrite', child: Text('Rewrite')),
              DropdownMenuItem(value: 'simplify', child: Text('Simplify')),
              DropdownMenuItem(value: 'grammar', child: Text('Grammar')),
              DropdownMenuItem(value: 'tone', child: Text('Change tone')),
              DropdownMenuItem(value: 'explain_terms', child: Text('Explain terms')),
            ],
            onChanged: (value) => writingMode = value ?? writingMode,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: tone,
            items: const ['professional', 'friendly', 'formal', 'concise', 'academic']
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) => tone = value ?? tone,
          ),
        ],
      ),
    );
    if (accepted != null) await _run(operation: 'writing', mode: writingMode, tone: tone);
  }

  Future<T?> _choose<T>(String title, Widget child) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: child,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
        ],
      ),
    );
  }

  Future<void> _run({
    required String operation,
    String? mode,
    String difficulty = 'medium',
    String language = 'English',
    String tone = 'professional',
  }) async {
    if (!state.hasConsentForSelectedDocument()) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow document sharing?'),
          content: Text('The source text will be sent to ${state.provider} for this AI tool.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Allow')),
          ],
        ),
      );
      if (approved != true) return;
      state.grantConsentForSelectedDocument();
    }
    await state.generateAiTool(
      operation: operation,
      text: textController.text.trim(),
      mode: mode,
      difficulty: difficulty,
      language: language,
      tone: tone,
    );
  }

  Widget _itemCard(int index, Map<String, dynamic> item) {
    final front = item['front'] ?? item['question'] ?? '';
    final back = item['back'] ?? item['answer'] ?? '';
    final options = (item['options'] as List<dynamic>? ?? const []).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('$index. $front'),
        subtitle: Text([if (options.isNotEmpty) 'Options: $options', if (back.toString().isNotEmpty) 'Answer: $back'].join('\n')),
      ),
    );
  }
}
