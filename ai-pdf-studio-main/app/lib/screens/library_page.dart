import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({required this.state, super.key, this.filtered = false});

  final AppState state;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final documents = filtered
        ? state.documents.where((document) {
            if (state.navigationIndex == 2) return document.favorite;
            return true;
          }).toList()
        : state.documents;
    return DropTarget(
      onDragDone: (detail) {
        for (final file in detail.files) {
          if (file.path.toLowerCase().endsWith('.pdf')) {
            state.importDocument(file.path);
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.navigationIndex == 2 ? 'Favorites' : 'Your library',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text('${documents.length} documents · All stored locally', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: state.pickAndImport,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Import PDF'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _StatCard(label: 'All documents', value: '${state.documents.length}', icon: Icons.description_outlined),
              const SizedBox(width: 12),
              _StatCard(label: 'Favorites', value: '${state.documents.where((d) => d.favorite).length}', icon: Icons.star_outline_rounded),
            ],
          ),
          const SizedBox(height: 28),
          const SectionLabel('Recent documents'),
          const SizedBox(height: 12),
          Expanded(
            child: state.contentSearchMode && state.searchController.text.trim().isNotEmpty
                ? _ContentSearchResults(state: state)
                : documents.isEmpty
                ? _EmptyLibrary(state: state, filtered: filtered)
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 330,
                      mainAxisExtent: 190,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: documents.length,
                    itemBuilder: (context, index) => _DocumentCard(state: state, document: documents[index]),
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ContentSearchResults extends StatelessWidget {
  const _ContentSearchResults({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.contentMatches.isEmpty) {
      return Center(child: Text('Submit a search to find text inside indexed PDFs.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }
    return ListView.separated(
      itemCount: state.contentMatches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final match = state.contentMatches[index];
        return SurfaceCard(
          child: ListTile(
            leading: const Icon(Icons.find_in_page_outlined),
            title: Text(match.path.split(RegExp(r'[/\\]')).last),
            subtitle: Text('Page ${match.pageNumber}: ${match.snippet}'),
            onTap: () => state.openSearchMatch(match),
          ),
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
    const _EmptyLibrary({required this.state, required this.filtered});

    final AppState state;
    final bool filtered;

    @override
    Widget build(BuildContext context) {
      final title = filtered && state.navigationIndex == 2 ? 'No favorites yet' : 'Your library is ready';
      final message = filtered && state.navigationIndex == 2
          ? 'Star a document to keep it close at hand.'
          : 'Import a PDF to start reading, searching, and asking questions.';
      return Center(
        child: SurfaceCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined, size: 42, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (!filtered || state.navigationIndex != 2) ...[
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: state.pickAndImport, icon: const Icon(Icons.add), label: const Text('Import PDF')),
              ],
            ],
          ),
        ),
      );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SurfaceCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.state, required this.document});

  final AppState state;
  final PdfDocumentModel document;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => state.selectDocument(document),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.picture_as_pdf_outlined, color: Theme.of(context).colorScheme.primary),
                  ),
                  const Spacer(),
                  AppIconButton(
                    icon: document.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    tooltip: 'Favorite',
                    active: document.favorite,
                    onPressed: () => state.toggleFavorite(document),
                  ),
                  AppIconButton(icon: Icons.more_horiz, tooltip: 'More actions', onPressed: () => _showActions(context)),
                ],
              ),
              if (document.status == 'missing') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 15, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 5),
                    Expanded(child: Text('Source file is missing', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error))),
                    TextButton(onPressed: () => _locate(context), child: const Text('Locate')),
                  ],
                ),
              ],
              const Spacer(),
              Text(document.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('${document.pages} pages  ·  ${document.updated}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (document.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(document.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.edit_note), title: const Text('Edit note'), onTap: () { Navigator.pop(context); _editNote(context); }),
            ListTile(leading: const Icon(Icons.local_offer_outlined), title: const Text('Edit tags'), onTap: () { Navigator.pop(context); _editTags(context); }),
            ListTile(leading: const Icon(Icons.add_to_photos_outlined), title: const Text('Add to workspace'), onTap: () { Navigator.pop(context); _addToWorkspace(context); }),
            if (document.status == 'missing') ListTile(leading: const Icon(Icons.link), title: const Text('Locate source file'), onTap: () { Navigator.pop(context); _locate(context); }),
            ListTile(leading: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error), title: const Text('Remove from library'), onTap: () { Navigator.pop(context); state.removeFromLibrary(document); }),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final controller = TextEditingController(text: document.note);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document note'),
        content: TextField(controller: controller, autofocus: true, maxLines: 5, decoration: const InputDecoration(hintText: 'Add a note about this document')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save'))],
      ),
    );
    controller.dispose();
    if (note != null) await state.saveNote(document, note);
  }

  Future<void> _editTags(BuildContext context) async {
    final controller = TextEditingController(text: document.tags.join(', '));
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document tags'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'work, review, project')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save'))],
      ),
    );
    controller.dispose();
    if (value != null) await state.saveTags(document, value.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList());
  }

  Future<void> _addToWorkspace(BuildContext context) async {
    if (state.workspaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a workspace first.')));
      return;
    }
    final workspace = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add to workspace'),
        children: state.workspaces.map((item) => SimpleDialogOption(onPressed: () => Navigator.pop(context, item.name), child: Text(item.name))).toList(),
      ),
    );
    if (workspace != null) await state.addToWorkspace(workspace, document);
  }

  Future<void> _locate(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    final path = result?.files.single.path;
    if (path != null) await state.relocateDocument(document, path);
  }
}
