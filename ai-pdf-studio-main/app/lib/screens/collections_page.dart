import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';

enum CollectionKind { folders, tags, workspaces }

class CollectionsPage extends StatelessWidget {
  const CollectionsPage({required this.state, required this.kind, super.key});

  final AppState state;
  final CollectionKind kind;

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      CollectionKind.folders => 'Folders',
      CollectionKind.tags => 'Tags',
      CollectionKind.workspaces => 'Workspaces',
    };
    final icon = switch (kind) {
      CollectionKind.folders => Icons.folder_open_outlined,
      CollectionKind.tags => Icons.local_offer_outlined,
      CollectionKind.workspaces => Icons.workspaces_outlined,
    };
    final items = switch (kind) {
      CollectionKind.folders => state.folders,
      CollectionKind.tags => state.tags,
      CollectionKind.workspaces => state.workspaces.map((item) => item.name).toList(),
    };
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700))),
              if (kind == CollectionKind.workspaces)
                FilledButton.icon(onPressed: () => _createWorkspace(context), icon: const Icon(Icons.add), label: const Text('New workspace')),
            ],
          ),
          const SizedBox(height: 8),
          Text('${items.length} ${title.toLowerCase()}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text('No $title yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return SurfaceCard(
                        child: ListTile(
                          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                          title: Text(item is LibraryWorkspace ? item.name : item.toString()),
                          subtitle: kind == CollectionKind.folders ? Text(item.toString()) : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            if (kind == CollectionKind.folders) state.selectFolder(item.toString());
                            if (kind == CollectionKind.tags) state.selectTag(item.toString());
                            if (kind == CollectionKind.workspaces) state.selectWorkspace(item.toString());
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _createWorkspace(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New workspace'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) await state.createWorkspace(name);
  }
}
