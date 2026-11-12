import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/common.dart';
import 'chat_panel.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final document = state.selectedDocument!;
    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 17),
              const SizedBox(width: 9),
              Expanded(child: Text(document.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              AppIconButton(icon: Icons.undo_rounded, tooltip: 'Undo', onPressed: () {}),
              AppIconButton(icon: Icons.redo_rounded, tooltip: 'Redo', onPressed: () {}),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.ios_share, size: 16), label: const Text('Export')),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              const _ThumbnailRail(),
              Expanded(child: _PdfCanvas(documentName: document.name, pages: document.pages)),
              if (state.chatOpen) SizedBox(width: 330, child: ChatPanel(state: state)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThumbnailRail extends StatelessWidget {
  const _ThumbnailRail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor))),
      child: ListView.separated(
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Container(
          height: 78,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: index == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined, size: 23, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 5),
              Text('${index + 1}', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfCanvas extends StatelessWidget {
  const _PdfCanvas({required this.documentName, required this.pages});

  final String documentName;
  final int pages;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF090D14) : const Color(0xFFE6E9EF),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                AppIconButton(icon: Icons.zoom_out, tooltip: 'Zoom out', onPressed: () {}),
                const Text('100%', style: TextStyle(fontSize: 12)),
                AppIconButton(icon: Icons.zoom_in, tooltip: 'Zoom in', onPressed: () {}),
                const Spacer(),
                Text('Page 1 of $pages', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 15),
                AppIconButton(icon: Icons.chat_bubble_outline, tooltip: 'Toggle AI assistant', onPressed: () {}),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: .72,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.fromLTRB(42, 48, 42, 38),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 130, height: 8, color: const Color(0xFF273044)),
                      const SizedBox(height: 16),
                      Text(documentName.replaceAll('.pdf', ''), style: const TextStyle(color: Color(0xFF182033), fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 28),
                      for (var index = 0; index < 12; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: FractionallySizedBox(
                            widthFactor: index % 4 == 0 ? .8 : .96,
                            child: Container(height: 5, color: const Color(0xFFD8DDE7)),
                          ),
                        ),
                      const Spacer(),
                      const Text('AI PDF Studio  ·  Preview', style: TextStyle(color: Color(0xFF9AA4B6), fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
