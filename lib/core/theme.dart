import 'package:flutter/material.dart';
import '../models/safety.dart';

const ink = Color(0xFF142C36);
const canvas = Color(0xFFF3F6F8);
const panel = Color(0xFFFFFFFF);
const line = Color(0xFFE5EBEF);
const muted = Color(0xFF73818C);
const green = Color(0xFF0C614E);
const orange = Color(0xFFC5800B);
const red = Color(0xFFE95157);
const liveGreen = Color(0xFF29E8A0);
Color severityColor(Severity s) => switch (s) {
  Severity.safe => green,
  Severity.info => muted,
  Severity.warning || Severity.high => orange,
  Severity.critical => red,
};
Color zoneColor(ZoneType t) => switch (t) {
  ZoneType.work => green,
  ZoneType.restricted => red,
  ZoneType.highRisk => orange,
};
ThemeData safetyTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: canvas,
  colorScheme: const ColorScheme.light(
    primary: green,
    secondary: green,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFDDF2E9),
    onSecondaryContainer: green,
    outline: line,
    surface: panel,
    error: red,
    onSurface: ink,
    onPrimary: Colors.white,
  ),
  fontFamily: 'PlexArabic',
  fontFamilyFallback: const ['Arial'],
  appBarTheme: const AppBarTheme(
    backgroundColor: canvas,
    foregroundColor: ink,
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: panel,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: line),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: canvas,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFDDF2E9),
    height: 74,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(44, 54),
      foregroundColor: Colors.white,
      backgroundColor: green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 1.4,
    ),
    headlineMedium: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
  ),
);
