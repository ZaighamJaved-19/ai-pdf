import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({required this.title, required this.onBack, super.key});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final content = switch (title) {
      'About' => ('AI PDF Studio', 'A local-first Windows PDF workspace with PDFium rendering and optional OpenAI-powered document assistance.'),
      'Feedback' => ('Share feedback', 'Tell us what worked, what felt difficult, and which PDF workflows would make your day easier.\n\nEmail: feedback@example.com'),
      'Help' => ('Help center', 'Import a PDF from Library, open it in Reader, then use the Reading and AI modes in the top bar. Ctrl+O opens a file, Ctrl+F searches, and Esc exits full screen.'),
      'Privacy policy' => ('Privacy policy', 'Your document files and reading history remain on this device. AI requests are sent only after you configure a provider and submit a document question.'),
      _ => ('Terms of use', 'Use AI PDF Studio responsibly and review generated answers before relying on them. You are responsible for the documents and credentials you provide.'),
    };
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        title: Text(content.$1),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(content.$2, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
          ),
        ),
      ),
    );
  }
}
