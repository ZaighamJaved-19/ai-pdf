import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({required this.state, super.key});

  final AppState state;

  static const tools = [
    ToolDefinition('Merge PDFs', 'Combine multiple documents into one', Icons.merge_type, Color(0xFF7C83FD)),
    ToolDefinition('Split PDF', 'Extract pages into separate files', Icons.call_split, Color(0xFF4DB6AC)),
    ToolDefinition('Compress', 'Reduce file size while preserving quality', Icons.compress, Color(0xFFF4A261)),
    ToolDefinition('OCR', 'Make scanned documents searchable', Icons.document_scanner_outlined, Color(0xFFE76F51)),
    ToolDefinition('Redact', 'Permanently remove sensitive content', Icons.visibility_off_outlined, Color(0xFFE85D75)),
    ToolDefinition('Password protect', 'Encrypt a PDF and control permissions', Icons.lock_outline, Color(0xFF6C63FF)),
    ToolDefinition('Remove password', 'Create an unlocked copy of a PDF', Icons.lock_open_outlined, Color(0xFF8E6CFF)),
    ToolDefinition('Remove metadata', 'Strip author and title metadata', Icons.cleaning_services_outlined, Color(0xFF2A9D8F)),
    ToolDefinition('Digital signature', 'Create or validate a detached signature', Icons.draw_outlined, Color(0xFF457B9D)),
    ToolDefinition('Compare', 'Find changes between two documents', Icons.compare_arrows, Color(0xFF5DADE2)),
    ToolDefinition('Convert', 'Convert files to or from PDF', Icons.swap_horiz, Color(0xFF9B8AFB)),
    ToolDefinition('Page editor', 'Reorder, rotate, and delete pages', Icons.dashboard_customize_outlined, Color(0xFF55B98A)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PDF tools', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text('Local processing · Your files never leave your computer', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 320, mainAxisExtent: 138, crossAxisSpacing: 14, mainAxisSpacing: 14),
              itemCount: tools.length,
              itemBuilder: (context, index) => _ToolCard(tool: tools[index], onTap: () => _showTool(context, tools[index])),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTool(BuildContext context, ToolDefinition tool) async {
    if (tool.label == 'Merge PDFs') {
      final files = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      final paths = files?.files.map((file) => file.path).whereType<String>().toList() ?? const [];
      if (paths.isEmpty) return;
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Save merged PDF',
        fileName: 'merged.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (output != null) await state.mergePdfFiles(paths, output);
      return;
    }
    if (tool.label == 'Split PDF' && state.readerPdfPath != null) {
      final directory = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose split output folder');
      if (directory != null) await state.splitCurrentPdf(directory);
      return;
    }
    if (tool.label == 'Compress' && state.readerPdfPath != null) {
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Save compressed PDF',
        fileName: 'compressed.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (output != null) await state.compressCurrentPdf(output);
      return;
    }
    if (tool.label == 'Password protect' && state.readerPdfPath != null) {
      await _protectDialog(context);
      return;
    }
    if (tool.label == 'Remove password' && state.readerPdfPath != null) {
      await _removePasswordDialog(context);
      return;
    }
    if (tool.label == 'Remove metadata' && state.readerPdfPath != null) {
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Save metadata-free PDF',
        fileName: 'metadata-removed.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (output != null) await state.removeMetadataFromCurrentPdf(output);
      return;
    }
    if (tool.label == 'Redact' && state.readerPdfPath != null) {
      await _redactDialog(context);
      return;
    }
    if (tool.label == 'Digital signature' && state.readerPdfPath != null) {
      await _signatureDialog(context);
      return;
    }
    if (tool.label == 'Page editor') {
      state.setTool('Reader');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tool.label),
        content: Text('${tool.description}. Select a PDF from the library to begin this local workflow.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Choose from library')),
        ],
      ),
    );
  }

  Future<void> _protectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password protect PDF'),
        content: TextField(controller: controller, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'User password')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return;
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Save protected PDF',
      fileName: 'protected.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (output != null) await state.protectCurrentPdf(password, output, permissions: const ['print']);
  }

  Future<void> _removePasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove PDF password'),
        content: TextField(controller: controller, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'Current password')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return;
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Save unlocked PDF',
      fileName: 'unlocked.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (output != null) await state.removePasswordFromCurrentPdf(password, output);
  }

  Future<void> _redactDialog(BuildContext context) async {
    final controller = TextEditingController();
    final term = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redact search term'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Text to remove')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Find and redact')),
        ],
      ),
    );
    controller.dispose();
    if (term == null || term.trim().isEmpty) return;
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Save redacted PDF',
      fileName: 'redacted.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (output != null) await state.redactCurrentPdf(output, terms: [term.trim()]);
  }

  Future<void> _signatureDialog(BuildContext context) async {
    final key = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a PEM private key',
      type: FileType.custom,
      allowedExtensions: const ['pem', 'key'],
    );
    final keyPath = key?.files.single.path;
    if (keyPath == null) return;
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Save detached signature',
      fileName: '${state.selectedDocument?.name ?? 'document'}.sig',
      type: FileType.custom,
      allowedExtensions: const ['sig'],
    );
    if (output == null) return;
    final signature = await state.container.pdfEditor.sign(
      inputPath: state.readerPdfPath!,
      signaturePath: output,
      privateKeyPath: keyPath,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signature saved: $signature')));
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool, required this.onTap});

  final ToolDefinition tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: tool.color.withOpacity(.14), borderRadius: BorderRadius.circular(11)), child: Icon(tool.icon, color: tool.color)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(tool.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(tool.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, height: 1.3, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
