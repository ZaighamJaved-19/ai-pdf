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
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text('Configure your workspace and AI provider', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 28),
        _SettingsSection(
          title: 'Appearance',
          subtitle: 'Make AI PDF Studio feel like yours',
          child: Column(children: [
            _SettingRow(label: 'Theme', description: 'Choose between light, dark, or system appearance', trailing: SegmentedButton<ThemeMode>(
              segments: const [ButtonSegment(value: ThemeMode.light, label: Text('Light')), ButtonSegment(value: ThemeMode.dark, label: Text('Dark')), ButtonSegment(value: ThemeMode.system, label: Text('System'))],
              selected: {widget.state.themeMode},
              onSelectionChanged: (value) { widget.state.themeMode = value.first; widget.state.notifyListeners(); },
            )),
          ]),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'AI provider',
          subtitle: 'Keys are kept locally and sent only with your consent',
          child: Column(children: [
            _SettingRow(label: 'Provider', description: 'The service used for document questions', trailing: DropdownButton<String>(value: widget.state.provider, items: const [DropdownMenuItem(value: 'OpenAI', child: Text('OpenAI'))], onChanged: (_) {})),
            const Divider(height: 28),
            TextField(controller: keyController, obscureText: true, decoration: const InputDecoration(labelText: 'OpenAI API key', hintText: 'sk-…', prefixIcon: Icon(Icons.key_outlined))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(value: widget.state.model, decoration: const InputDecoration(labelText: 'Model'), items: const [DropdownMenuItem(value: 'gpt-4o-mini', child: Text('GPT-4o mini')), DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o'))], onChanged: (value) { if (value != null) widget.state.model = value; })),
              const SizedBox(width: 12),
              FilledButton(onPressed: () => widget.state.saveProviderSettings(keyController.text, widget.state.model), child: const Text('Save locally')),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Privacy',
          subtitle: 'Control what leaves your device',
          child: Column(children: [
            _SettingRow(label: 'Document consent', description: 'AI requests require explicit per-document approval', trailing: const Chip(label: Text('Always required'))),
            const Divider(height: 28),
            _SettingRow(label: 'Telemetry', description: 'Share anonymous, content-free diagnostics', trailing: Switch(value: false, onChanged: (_) {})),
          ]),
        ),
      ],
    );
  }
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
      trailing,
    ]);
  }
}
