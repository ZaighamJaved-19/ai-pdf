import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/app_shell.dart';
import 'theme.dart';

class AiPdfApp extends StatefulWidget {
  const AiPdfApp({super.key});

  @override
  State<AiPdfApp> createState() => _AiPdfAppState();
}

class _AiPdfAppState extends State<AiPdfApp> {
  final state = AppState();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        title: 'AI PDF Studio',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: state.themeMode,
        home: AppShell(state: state),
      ),
    );
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }
}
