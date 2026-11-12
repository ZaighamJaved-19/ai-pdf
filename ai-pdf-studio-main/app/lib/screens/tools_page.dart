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

  void _showTool(BuildContext context, ToolDefinition tool) {
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
