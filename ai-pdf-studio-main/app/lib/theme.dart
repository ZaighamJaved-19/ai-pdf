import 'package:flutter/material.dart';

const _ink = Color(0xFFE9EEF8);
const _muted = Color(0xFF8C98AD);
const _surface = Color(0xFF151B28);
const _panel = Color(0xFF101621);
const _accent = Color(0xFF6D7CFF);

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
    surface: _surface,
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0B1018),
    cardColor: _surface,
    dividerColor: const Color(0xFF273044),
    fontFamily: 'Segoe UI',
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _panel,
      hintStyle: const TextStyle(color: _muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF273044)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF273044)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _accent, width: 1.4),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: _panel,
      selectedIconTheme: IconThemeData(color: _ink),
      unselectedIconTheme: IconThemeData(color: _muted),
      selectedLabelTextStyle: TextStyle(color: _ink, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: _muted),
    ),
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _accent),
    scaffoldBackgroundColor: const Color(0xFFF4F6FA),
    fontFamily: 'Segoe UI',
    useMaterial3: true,
  );
}
