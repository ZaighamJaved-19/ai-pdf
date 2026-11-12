import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
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
              _ThumbnailRail(pages: state.selectedDetails?.pages ?? const []),
              Expanded(child: _PdfTextViewer(details: state.selectedDetails)),
              if (state.chatOpen) SizedBox(width: 330, child: ChatPanel(state: state)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThumbnailRail extends StatelessWidget {
  const _ThumbnailRail({required this.pages});

  final List<PdfPageModel> pages;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const SizedBox(width: 92);
    }
    return Container(
      width: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor))),
      child: ListView.separated(
        itemCount: pages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Container(
          height: 78,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: index == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
          ),
          child: Center(child: Text('${pages[index].pageNumber}', style: const TextStyle(fontSize: 11))),
        ),
      ),
    );
  }
}

class _PdfTextViewer extends StatelessWidget {
  const _PdfTextViewer({required this.details});

  final PdfDocumentDetails? details;

  @override
  Widget build(BuildContext context) {
    if (details == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (details!.pages.isEmpty) {
      return const Center(child: Text('This PDF has no extractable text.'));
    }
    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF090D14) : const Color(0xFFE6E9EF),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                AppIconButton(icon: Icons.zoom_out, tooltip: 'Zoom out', onPressed: () {}),
                const Text('Text view', style: TextStyle(fontSize: 12)),
                AppIconButton(icon: Icons.zoom_in, tooltip: 'Zoom in', onPressed: () {}),
                const Spacer(),
                Text('${details!.pages.length} pages', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 15),
                AppIconButton(icon: Icons.chat_bubble_outline, tooltip: 'Toggle AI assistant', onPressed: () {}),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(40, 10, 40, 30),
              itemCount: details!.pages.length,
              itemBuilder: (context, index) => _PageText(page: details!.pages[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageText extends StatelessWidget {
  const _PageText({required this.page});

  final PdfPageModel page;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(28),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Page ${page.pageNumber}', style: const TextStyle(color: Color(0xFF6D7CFF), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SelectableText(
            page.text.isEmpty ? '[No extractable text on this page]' : page.text,
            style: const TextStyle(color: Color(0xFF182033), height: 1.55, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
