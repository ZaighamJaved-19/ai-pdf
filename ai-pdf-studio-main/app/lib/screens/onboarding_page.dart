import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/common.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.auto_awesome, size: 38),
                ),
                const SizedBox(height: 24),
                Text('Welcome to AI PDF Studio', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  'A focused Windows workspace for reading, organizing, and understanding your PDFs with AI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 15),
                ),
                const SizedBox(height: 30),
                Row(
                  children: const [
                    Expanded(child: _OnboardingFeature(icon: Icons.picture_as_pdf_outlined, title: 'Read comfortably', text: 'Fast PDFium rendering, search, selection, and flexible page layouts.')),
                    SizedBox(width: 14),
                    Expanded(child: _OnboardingFeature(icon: Icons.auto_awesome_outlined, title: 'Ask your documents', text: 'Use your consented OpenAI connection for grounded document questions.')),
                    SizedBox(width: 14),
                    Expanded(child: _OnboardingFeature(icon: Icons.lock_outline, title: 'Stay in control', text: 'Your library stays local and settings are saved on this device.')),
                  ],
                ),
                const SizedBox(height: 34),
                FilledButton.icon(
                  onPressed: state.completeOnboarding,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Start reading'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingFeature extends StatelessWidget {
  const _OnboardingFeature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
