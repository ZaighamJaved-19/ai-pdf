import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'chat_panel.dart';

enum ReaderMode { continuous, single, double }

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({required this.state, super.key});

  final AppState state;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  ReaderMode mode = ReaderMode.continuous;
  final searchController = TextEditingController();
  final readerKey = GlobalKey<_PdfReaderState>();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.state.selectedDocument!;
    final readerPath = widget.state.readerPdfPath ?? document.path;
    return Column(
      children: [
        _TabBar(state: widget.state),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 17),
              const SizedBox(width: 9),
              Expanded(child: Text(document.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              AppIconButton(icon: Icons.bookmark_border, tooltip: 'Bookmark page', onPressed: () => _bookmark(context)),
              AppIconButton(icon: Icons.info_outline, tooltip: 'Metadata', onPressed: () => _metadata(context)),
              AppIconButton(icon: Icons.undo, tooltip: 'Undo edit', onPressed: widget.state.canUndoEdit ? widget.state.undoPdfEdit : null),
              AppIconButton(icon: Icons.redo, tooltip: 'Redo edit', onPressed: widget.state.canRedoEdit ? widget.state.redoPdfEdit : null),
              AppIconButton(icon: Icons.info_outline, tooltip: 'Editing policy', onPressed: () => _textPolicy(context)),
              PopupMenuButton<String>(
                tooltip: 'Annotate',
                onSelected: (value) => _annotationAction(context, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'highlight', child: Text('Highlight')),
                  PopupMenuItem(value: 'underline', child: Text('Underline')),
                  PopupMenuItem(value: 'strikethrough', child: Text('Strikethrough')),
                  PopupMenuItem(value: 'comment', child: Text('Comment')),
                  PopupMenuItem(value: 'sticky', child: Text('Sticky note')),
                  PopupMenuItem(value: 'freehand', child: Text('Freehand')),
                  PopupMenuItem(value: 'arrow', child: Text('Arrow')),
                  PopupMenuItem(value: 'rectangle', child: Text('Rectangle')),
                  PopupMenuItem(value: 'circle', child: Text('Circle')),
                  PopupMenuItem(value: 'signature', child: Text('Signature')),
                  PopupMenuItem(value: 'image', child: Text('Insert image')),
                  PopupMenuItem(value: 'text', child: Text('Add text')),
                ],
                child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.draw_outlined, size: 19)),
              ),
              PopupMenuButton<String>(
                tooltip: 'Page operations',
                onSelected: (value) => _pageOperation(context, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'extract', child: Text('Extract selected pages')),
                  PopupMenuItem(value: 'crop', child: Text('Crop current page')),
                  PopupMenuItem(value: 'headerFooter', child: Text('Headers, footers, watermark')),
                  PopupMenuItem(value: 'deletePage', child: Text('Delete current page')),
                ],
                child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.layers_outlined, size: 19)),
              ),
              AppIconButton(icon: Icons.save_outlined, tooltip: 'Save', onPressed: widget.state.savePdf),
              AppIconButton(icon: Icons.save_as_outlined, tooltip: 'Save As', onPressed: widget.state.savePdfAs),
              AppIconButton(icon: Icons.print_outlined, tooltip: 'Print', onPressed: widget.state.printSelected),
              AppIconButton(icon: widget.state.chatOpen ? Icons.forum : Icons.forum_outlined, tooltip: widget.state.chatOpen ? 'Collapse AI panel' : 'Open AI panel', active: widget.state.chatOpen, onPressed: widget.state.toggleChat),
              AppIconButton(icon: Icons.fullscreen, tooltip: 'Full screen', onPressed: widget.state.toggleReaderFullScreen),
            ],
          ),
        ),
        _ReaderToolbar(
          state: widget.state,
          mode: mode,
          searchController: searchController,
          searchFocusNode: widget.state.readerSearchFocusNode,
          onModeChanged: (value) => setState(() => mode = value),
          onSearch: () => readerKey.currentState?.search(searchController.text),
          onNext: () => readerKey.currentState?.nextMatch(),
          onPrevious: () => readerKey.currentState?.previousMatch(),
          onFitPage: () => readerKey.currentState?.fitPage(),
          onFitWidth: () => readerKey.currentState?.fitWidth(),
        ),
        Expanded(
          child: Row(
            children: [
              _ThumbnailRail(
                path: readerPath,
                initialPage: document.lastPage,
                onPageTap: (page) => readerKey.currentState?.goToPage(page),
                onPassword: () => _passwordDialog(context),
              ),
              Expanded(child: _PdfReader(
                key: readerKey,
                path: readerPath,
                initialPage: document.lastPage,
                mode: mode,
                zoom: widget.state.readerZoom,
                cacheEnabled: widget.state.cacheEnabled,
                onPageChanged: (page) {
                  if (page != null) {
                    widget.state.currentPage = page;
                    unawaited(widget.state.saveLastPage(page));
                  }
                },
                onPassword: () => _passwordDialog(context),
              )),
              if (widget.state.chatOpen) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) => widget.state.setAiPanelWidth(widget.state.aiPanelWidth - details.delta.dx),
                    child: const SizedBox(width: 5),
                  ),
                ),
                SizedBox(
                  width: widget.state.aiPanelWidth,
                  child: ChatPanel(
                    state: widget.state,
                    onCitationPage: (page) => readerKey.currentState?.goToPage(page),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _passwordDialog(BuildContext context) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password-protected PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Open')),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  void _metadata(BuildContext context) {
    final details = widget.state.selectedDetails;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.state.selectedDocument!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(widget.state.selectedDocument!.path),
            const SizedBox(height: 8),
            Text('${details?.pageCount ?? 0} pages'),
            if (details?.title != null) Text('Title: ${details!.title}'),
            if (details?.author != null) Text('Author: ${details!.author}'),
            if (details?.fileSizeBytes != null) Text('Size: ${details!.fileSizeBytes} bytes'),
            if (details?.encrypted == true) const Text('Encrypted: yes'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _bookmark(BuildContext context) {
    widget.state.bookmarks.add(widget.state.currentPage);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bookmarked page ${widget.state.currentPage}')));
  }

  void _textPolicy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF editing policy'),
        content: const Text(
          'AI PDF Studio adds annotations, overlays, and page-level changes. '
          'It does not silently rewrite existing PDF text. Existing text is only changed through an explicit reconstruction workflow, which is not enabled here.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _annotationAction(BuildContext context, String type) async {
    if (type == 'image' || type == 'signature') {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path == null) return;
      await widget.state.applyPdfEdit(
        images: [
          {
            'page': widget.state.currentPage,
            'path': path,
            'x': 50,
            'y': 50,
            'width': type == 'signature' ? 180 : 240,
            'height': type == 'signature' ? 70 : 180,
          },
        ],
        label: type,
      );
      return;
    }
    if (type == 'text') {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add text annotation'),
          content: TextField(controller: controller, minLines: 2, maxLines: 5, autofocus: true, decoration: const InputDecoration(labelText: 'Text')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
          ],
        ),
      );
      controller.dispose();
      if (value == null || value.trim().isEmpty) return;
      await widget.state.applyPdfEdit(
        text: [
          {'page': widget.state.currentPage, 'text': value, 'x': 50, 'y': 650, 'width': 300, 'height': 40},
        ],
        label: 'text',
      );
      return;
    }
    if (type == 'freehand') {
      final points = await _freehandDialog(context);
      if (points == null || points.length < 2) return;
      await widget.state.applyPdfEdit(
        annotations: [
          {
            'page': widget.state.currentPage,
            'type': 'freehand',
            'points': points,
            'x': 0,
            'y': 0,
            'width': 300,
            'height': 300,
          },
        ],
        label: 'freehand',
      );
      return;
    }
    final contents = await _annotationContents(context, type);
    if (contents == null && (type == 'comment' || type == 'sticky')) return;
    final item = <String, dynamic>{
      'page': widget.state.currentPage,
      'type': type,
      'x': 50,
      'y': 650,
      'width': type == 'freehand' ? 160 : 180,
      'height': type == 'freehand' ? 80 : 30,
      'contents': contents ?? '',
    };
    if (type == 'arrow') {
      item['x1'] = 50;
      item['y1'] = 650;
      item['x2'] = 230;
      item['y2'] = 700;
    }
    await widget.state.applyPdfEdit(annotations: [item], label: type);
  }

  Future<String?> _annotationContents(BuildContext context, String type) async {
    if (type != 'comment' && type != 'sticky') return '';
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'sticky' ? 'Sticky note' : 'Comment'),
        content: TextField(controller: controller, minLines: 2, maxLines: 5, autofocus: true, decoration: const InputDecoration(labelText: 'Note')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _pageOperation(BuildContext context, String operation) async {
    if (operation == 'deletePage') {
      await widget.state.transformPdf(delete: [widget.state.currentPage - 1]);
      return;
    }
    if (operation == 'extract') {
      final controller = TextEditingController(text: '${widget.state.currentPage}');
      final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Extract pages'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Pages (for example 1,3-5)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Extract')),
          ],
        ),
      );
      controller.dispose();
      if (value == null) return;
      final pages = _parsePageSelection(value);
      if (pages.isNotEmpty) await widget.state.extractPdfPages(pages);
      return;
    }
    if (operation == 'crop') {
      final values = await _cropDialog(context);
      if (values != null) {
        await widget.state.applyPdfEdit(
          crop: {'page': widget.state.currentPage.toDouble(), ...values},
          label: 'crop',
        );
      }
      return;
    }
    final values = await _headerFooterDialog(context);
    if (values != null) {
      await widget.state.applyPdfEdit(
        header: values['header'],
        footer: values['footer'],
        watermark: values['watermark'],
        label: 'overlay',
      );
    }
  }

  List<int> _parsePageSelection(String value) {
    final pages = <int>{};
    for (final part in value.split(',')) {
      final range = part.trim().split('-').map((item) => int.tryParse(item.trim())).toList();
      if (range.length == 1 && range.first != null) pages.add(range.first!);
      if (range.length == 2 && range[0] != null && range[1] != null) {
        for (var page = range[0]!; page <= range[1]!; page++) pages.add(page);
      }
    }
    return pages.toList()..sort();
  }

  Future<Map<String, double>?> _cropDialog(BuildContext context) async {
    final controllers = {
      'x': TextEditingController(text: '0'),
      'y': TextEditingController(text: '0'),
      'width': TextEditingController(text: '550'),
      'height': TextEditingController(text: '750'),
    };
    final value = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crop current page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: controllers.entries
              .map((entry) => TextField(controller: entry.value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: entry.key)))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {for (final entry in controllers.entries) entry.key: double.tryParse(entry.value.text) ?? 0}),
            child: const Text('Crop'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) controller.dispose();
    return value;
  }

  Future<Map<String, String>?> _headerFooterDialog(BuildContext context) async {
    final controllers = {
      'header': TextEditingController(text: 'AI PDF Studio · {page}/{pages}'),
      'footer': TextEditingController(),
      'watermark': TextEditingController(),
    };
    final value = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Headers, footers and watermark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: controllers.entries
              .map((entry) => TextField(controller: entry.value, decoration: InputDecoration(labelText: entry.key)))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {for (final entry in controllers.entries) entry.key: entry.value.text}),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) controller.dispose();
    return value;
  }

  Future<List<List<double>>?> _freehandDialog(BuildContext context) {
    return showDialog<List<List<double>>>(
      context: context,
      builder: (context) {
        var points = <Offset>[];
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Draw freehand annotation'),
            content: SizedBox(
              width: 420,
              height: 260,
              child: GestureDetector(
                onPanStart: (details) => setState(() => points = [details.localPosition]),
                onPanUpdate: (details) => setState(() => points = [...points, details.localPosition]),
                child: ColoredBox(
                  color: const Color(0xFFF3F5F8),
                  child: CustomPaint(painter: _StrokePainter(points)),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  points.map((point) => <double>[point.dx, 760 - point.dy]).toList(),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => oldDelegate.points != points;
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.openDocuments.isEmpty) return const SizedBox(height: 1);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: state.openDocuments.map((document) {
          final selected = state.selectedDocument?.path == document.path;
          return InkWell(
            onTap: () => state.selectTab(document),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              padding: const EdgeInsets.only(left: 14, right: 7),
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).cardColor : Colors.transparent,
                border: Border(bottom: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 14),
                  const SizedBox(width: 7),
                  Flexible(child: Text(document.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  IconButton(onPressed: () => state.closeTab(document), icon: const Icon(Icons.close, size: 14), padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 25, height: 25)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({
    required this.state,
    required this.mode,
    required this.searchController,
    required this.searchFocusNode,
    required this.onModeChanged,
    required this.onSearch,
    required this.onNext,
    required this.onPrevious,
    required this.onFitPage,
    required this.onFitWidth,
  });

  final AppState state;
  final ReaderMode mode;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<ReaderMode> onModeChanged;
  final VoidCallback onSearch;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onFitPage;
  final VoidCallback onFitWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          AppIconButton(icon: Icons.zoom_out, tooltip: 'Zoom out', onPressed: () => state.zoomBy(-.1)),
          Text('${(state.readerZoom * 100).round()}%', style: const TextStyle(fontSize: 12)),
          AppIconButton(icon: Icons.zoom_in, tooltip: 'Zoom in', onPressed: () => state.zoomBy(.1)),
          PopupMenuButton<String>(
            tooltip: 'Fit',
            onSelected: (value) {
              if (value == 'page') onFitPage();
              if (value == 'width') onFitWidth();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'page', child: Text('Fit to page')),
              PopupMenuItem(value: 'width', child: Text('Fit to width')),
            ],
            child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.fit_screen, size: 18)),
          ),
          const VerticalDivider(width: 20),
          SegmentedButton<ReaderMode>(
            segments: const [
              ButtonSegment(value: ReaderMode.continuous, icon: Icon(Icons.view_agenda_outlined), label: Text('Continuous')),
              ButtonSegment(value: ReaderMode.single, icon: Icon(Icons.looks_one_outlined), label: Text('Single')),
              ButtonSegment(value: ReaderMode.double, icon: Icon(Icons.view_column_outlined), label: Text('Two page')),
            ],
            selected: {mode},
            onSelectionChanged: (value) => onModeChanged(value.first),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            height: 34,
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onSubmitted: (_) => onSearch(),
              decoration: InputDecoration(
                hintText: 'Find in document',
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: onPrevious, icon: const Icon(Icons.keyboard_arrow_up, size: 16)),
                    IconButton(onPressed: onNext, icon: const Icon(Icons.keyboard_arrow_down, size: 16)),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfReader extends StatefulWidget {
  const _PdfReader({
    required this.path,
    required this.initialPage,
    required this.mode,
    required this.zoom,
    required this.cacheEnabled,
    required this.onPageChanged,
    required this.onPassword,
    super.key,
  });

  final String path;
  final int initialPage;
  final ReaderMode mode;
  final double zoom;
  final bool cacheEnabled;
  final ValueChanged<int?> onPageChanged;
  final Future<String?> Function() onPassword;

  @override
  State<_PdfReader> createState() => _PdfReaderState();
}

class _PdfReaderState extends State<_PdfReader> {
  final controller = PdfViewerController();
  final singlePageKey = GlobalKey<_SinglePageReaderState>();
  late final PdfTextSearcher searcher;

  @override
  void initState() {
    super.initState();
    searcher = PdfTextSearcher(controller);
  }

  @override
  void didUpdateWidget(covariant _PdfReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom && controller.isReady) {
      unawaited(controller.setZoom(Offset.zero, widget.zoom));
    }
  }

  @override
  void dispose() {
    searcher.dispose();
    super.dispose();
  }

  void search(String value) {
    if (value.trim().isEmpty) {
      searcher.resetTextSearch();
      return;
    }
    searcher.startTextSearch(value.trim(), searchImmediately: true);
  }

  void nextMatch() {
    unawaited(searcher.goToNextMatch());
  }

  void previousMatch() {
    unawaited(searcher.goToPrevMatch());
  }

  void fitPage() {
    if (controller.isReady) unawaited(controller.setZoom(Offset.zero, controller.alternativeFitScale ?? 1));
  }

  void fitWidth() {
    if (controller.isReady) unawaited(controller.setZoom(Offset.zero, controller.coverScale));
  }

  void goToPage(int page) {
    if (widget.mode == ReaderMode.single) {
      singlePageKey.currentState?.goToPage(page);
    } else if (controller.isReady) {
      unawaited(controller.goToPage(pageNumber: page));
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = PdfViewerParams(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF090D14) : const Color(0xFFE6E9EF),
      maxImageBytesCachedOnMemory: widget.cacheEnabled ? 64 * 1024 * 1024 : 1,
      horizontalCacheExtent: widget.cacheEnabled ? .5 : 0,
      verticalCacheExtent: widget.cacheEnabled ? .75 : 0,
      enableTextSelection: true,
      pagePaintCallbacks: [searcher.pageTextMatchPaintCallback],
      onPageChanged: widget.onPageChanged,
      errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(child: Text('Unable to open PDF: $error')),
      layoutPages: widget.mode == ReaderMode.double ? _twoPageLayout : null,
    );
    if (widget.mode == ReaderMode.single) {
      return _SinglePageReader(
        key: singlePageKey,
        path: widget.path,
        initialPage: widget.initialPage,
        onPageChanged: widget.onPageChanged,
        onPassword: widget.onPassword,
      );
    }
    return PdfViewer.file(
      widget.path,
      key: ValueKey(widget.path),
      controller: controller,
      initialPageNumber: widget.initialPage,
      passwordProvider: widget.onPassword,
      params: params,
    );
  }

  static PdfPageLayout _twoPageLayout(List<PdfPage> pages, PdfViewerParams params) {
    final layouts = <Rect>[];
    var y = params.margin;
    for (var index = 0; index < pages.length; index += 2) {
      final left = pages[index];
      final right = index + 1 < pages.length ? pages[index + 1] : null;
      final rowHeight = right == null ? left.height : (left.height > right.height ? left.height : right.height);
      layouts.add(Rect.fromLTWH(params.margin, y + (rowHeight - left.height) / 2, left.width, left.height));
      if (right != null) {
        layouts.add(Rect.fromLTWH(params.margin * 2 + left.width, y + (rowHeight - right.height) / 2, right.width, right.height));
      }
      y += rowHeight + params.margin;
    }
    final width = layouts.fold<double>(0, (max, rect) => rect.right > max ? rect.right : max) + params.margin;
    return PdfPageLayout(pageLayouts: layouts, documentSize: Size(width, y));
  }
}

class _SinglePageReader extends StatefulWidget {
  const _SinglePageReader({required this.path, required this.initialPage, required this.onPageChanged, required this.onPassword});

  final String path;
  final int initialPage;
  final ValueChanged<int?> onPageChanged;
  final Future<String?> Function() onPassword;

  @override
  State<_SinglePageReader> createState() => _SinglePageReaderState();
}

class _SinglePageReaderState extends State<_SinglePageReader> {
  int page = 1;

  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    return PdfDocumentViewBuilder.file(
      widget.path,
      passwordProvider: widget.onPassword,
      builder: (context, document) {
        if (document == null) return const Center(child: CircularProgressIndicator());
        final total = document.pages.length;
        page = page.clamp(1, total).toInt();
        return Column(
          children: [
            Expanded(child: PdfPageView(document: document, pageNumber: page, alignment: Alignment.center)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: page > 1 ? () => setState(() { page--; widget.onPageChanged(page); }) : null, icon: const Icon(Icons.chevron_left)),
                Text('$page / $total'),
                IconButton(onPressed: page < total ? () => setState(() { page++; widget.onPageChanged(page); }) : null, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ],
        );
      },
    );
  }

  void goToPage(int value) {
    setState(() {
      page = value;
      widget.onPageChanged(page);
    });
  }
}

class _ThumbnailRail extends StatelessWidget {
  const _ThumbnailRail({
    required this.path,
    required this.initialPage,
    required this.onPageTap,
    required this.onPassword,
  });

  final String path;
  final int initialPage;
  final ValueChanged<int> onPageTap;
  final Future<String?> Function() onPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor))),
      child: PdfDocumentViewBuilder.file(
        path,
        passwordProvider: onPassword,
        builder: (context, document) {
          if (document == null) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: document.pages.length,
            itemBuilder: (context, index) => Container(
              key: ValueKey('thumbnail_${path}_$index'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(border: Border.all(color: index + 1 == initialPage ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor)),
              child: InkWell(
                onTap: () => onPageTap(index + 1),
                child: Column(
                  children: [
                    SizedBox(height: 100, child: PdfPageView(document: document, pageNumber: index + 1)),
                    Text('${index + 1}', style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
