import 'package:flutter/material.dart';

const _ink = Color(0xFFE9EEF8);
const _muted = Color(0xFF8C98AD);
const _surface = Color(0xFF151B28);
const _panel = Color(0xFF101621);
const _accent = Color(0xFF6D7CFF);
const _lightBackground = Color(0xFFF4F6FA);
const _lightSurface = Color(0xFFFFFFFF);
const _lightText = Color(0xFF182033);
const _lightMuted = Color(0xFF65708A);

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
    surface: _surface,
  );
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
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
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: _accent, brightness: Brightness.light, surface: _lightSurface),
    scaffoldBackgroundColor: _lightBackground,
    cardColor: _lightSurface,
    dividerColor: const Color(0xFFDCE2EE),
    fontFamily: 'Segoe UI',
    useMaterial3: true,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: _lightText),
      bodyLarge: TextStyle(color: _lightText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      hintStyle: const TextStyle(color: _lightMuted),
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFDCE2EE))),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFDCE2EE))),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _accent, width: 1.4)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: _lightSurface,
      selectedIconTheme: IconThemeData(color: _accent),
      unselectedIconTheme: IconThemeData(color: _lightMuted),
    ),
  );
}
