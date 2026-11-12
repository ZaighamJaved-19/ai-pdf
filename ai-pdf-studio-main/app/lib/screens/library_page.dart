import 'package:flutter/material.dart';

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
    return Padding(
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
              FilledButton.icon(onPressed: state.addDocument, icon: const Icon(Icons.add, size: 18), label: const Text('Import PDF')),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _StatCard(label: 'All documents', value: '${state.documents.length}', icon: Icons.description_outlined),
              const SizedBox(width: 12),
              _StatCard(label: 'Favorites', value: '${state.documents.where((d) => d.favorite).length}', icon: Icons.star_outline_rounded),
              const SizedBox(width: 12),
              const _StatCard(label: 'AI questions', value: '12', icon: Icons.auto_awesome_outlined),
            ],
          ),
          const SizedBox(height: 28),
          const SectionLabel('Recent documents'),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
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
                  AppIconButton(icon: Icons.more_horiz, tooltip: 'More actions', onPressed: () {}),
                ],
              ),
              const Spacer(),
              Text(document.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('${document.pages} pages  ·  ${document.updated}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
