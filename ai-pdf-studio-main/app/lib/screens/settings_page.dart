import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.state, super.key});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController keyController;

  @override
  void initState() {
    super.initState();
    keyController = TextEditingController(text: widget.state.apiKey);
  }

  @override
  void dispose() {
    keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text('Configure your workspace, reader, AI provider, and privacy choices', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 28),
        _SettingsSection(
          title: 'Appearance',
          subtitle: 'Make AI PDF Studio feel like yours',
          child: _SettingRow(
            label: 'Theme',
            description: 'Use the light, dark, or operating-system appearance',
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (value) => state.setThemeMode(value.first),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Reader',
          subtitle: 'Choose how documents open and render',
          child: Column(
            children: [
              _SettingRow(
                label: 'Default zoom',
                description: 'Zoom used when a new document is opened',
                trailing: SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<double>(
                    value: state.defaultZoom,
                    items: const [
                      DropdownMenuItem(value: .75, child: Text('75%')),
                      DropdownMenuItem(value: 1, child: Text('100%')),
                      DropdownMenuItem(value: 1.25, child: Text('125%')),
                      DropdownMenuItem(value: 1.5, child: Text('150%')),
                    ],
                    onChanged: (value) {
                      if (value != null) state.setDefaultZoom(value);
                    },
                  ),
                ),
              ),
              const Divider(height: 28),
              _SettingRow(
                label: 'Opening behavior',
                description: 'Choose where to resume a document',
                trailing: SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    value: state.openingBehavior,
                    items: const [
                      DropdownMenuItem(value: 'Restore last page', child: Text('Restore last page')),
                      DropdownMenuItem(value: 'Start from first page', child: Text('Start from first page')),
                    ],
                    onChanged: (value) {
                      if (value != null) state.setOpeningBehavior(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Files and storage',
          subtitle: 'Control exports, downloads, caching, and history',
          child: Column(
            children: [
              _SettingRow(
                label: 'Language',
                description: 'Interface language',
                trailing: _Dropdown<String>(value: state.language, values: const ['English', 'Spanish', 'French'], onChanged: state.setLanguage),
              ),
              const Divider(height: 28),
              _SettingRow(
                label: 'Export format',
                description: 'Default format for exported documents',
                trailing: _Dropdown<String>(value: state.exportFormat, values: const ['PDF', 'DOCX', 'PNG'], onChanged: state.setExportFormat),
              ),
              const Divider(height: 28),
              _SettingRow(
                label: 'Download folder',
                description: state.downloadFolder.isEmpty ? 'Use the system Downloads folder' : state.downloadFolder,
                trailing: OutlinedButton.icon(
                  onPressed: () async {
                    final path = await FilePicker.platform.getDirectoryPath();
                    if (path != null) state.setDownloadFolder(path);
                  },
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Choose'),
                ),
              ),
              const Divider(height: 28),
              _SettingRow(
                label: 'PDF render cache',
                description: 'Keep rendered pages in memory for smoother navigation',
                trailing: Switch(value: state.cacheEnabled, onChanged: state.setCacheEnabled),
              ),
              const Divider(height: 28),
              _SettingRow(
                label: 'Recent-document limit',
                description: 'Maximum number of documents shown in Recent',
                trailing: SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    value: state.recentDocumentLimit,
                    items: const [5, 10, 20, 50, 100].map((value) => DropdownMenuItem(value: value, child: Text('$value documents'))).toList(),
                    onChanged: (value) {
                      if (value != null) state.setRecentDocumentLimit(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'AI provider',
          subtitle: 'Keys are kept locally and sent only with your consent',
          child: Column(
            children: [
              _SettingRow(label: 'Provider', description: 'The service used for document questions', trailing: const Chip(label: Text('OpenAI'))),
              const Divider(height: 28),
              TextField(controller: keyController, obscureText: true, decoration: const InputDecoration(labelText: 'OpenAI API key', hintText: 'sk-…', prefixIcon: Icon(Icons.key_outlined))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: state.model,
                      decoration: const InputDecoration(labelText: 'Model'),
                      items: const [
                        DropdownMenuItem(value: 'gpt-4o-mini', child: Text('GPT-4o mini')),
                        DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o')),
                      ],
                      onChanged: (value) {
                        if (value != null) state.model = value;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: () => state.saveProviderSettings(keyController.text, state.model), child: const Text('Save locally')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Privacy',
          subtitle: 'Control what leaves your device',
          child: Column(
            children: [
              _SettingRow(label: 'Document consent', description: 'AI requests require explicit per-document approval', trailing: const Chip(label: Text('Always required'))),
              const Divider(height: 28),
              _SettingRow(label: 'Telemetry', description: 'Share anonymous, content-free diagnostics', trailing: Switch(value: false, onChanged: (_) {})),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'About and support',
          subtitle: 'Learn more or get help',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoButton(label: 'About', icon: Icons.info_outline, onPressed: () => state.openInfoPage('About')),
              _InfoButton(label: 'Help', icon: Icons.help_outline, onPressed: () => state.openInfoPage('Help')),
              _InfoButton(label: 'Feedback', icon: Icons.feedback_outlined, onPressed: () => state.openInfoPage('Feedback')),
              _InfoButton(label: 'Privacy policy', icon: Icons.privacy_tip_outlined, onPressed: () => state.openInfoPage('Privacy policy')),
              _InfoButton(label: 'Terms', icon: Icons.gavel_outlined, onPressed: () => state.openInfoPage('Terms')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.value, required this.values, required this.onChanged});

  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(value: value, items: values.map((item) => DropdownMenuItem(value: item, child: Text('$item'))).toList(), onChanged: (value) {
      if (value != null) onChanged(value);
    });
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.description, required this.trailing});

  final String label;
  final String description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(description, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      const SizedBox(width: 16),
      trailing,
    ]);
  }
}
