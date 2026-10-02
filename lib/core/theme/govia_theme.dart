import 'package:flutter/material.dart';

class GoViaColors {
  static const bg = Color(0xFF071019);
  static const panel = Color(0xFF0D1722);
  static const panel2 = Color(0xFF121E2A);
  static const border = Color(0xFF203140);
  static const text = Color(0xFFF7F9FB);
  static const muted = Color(0xFF8FA0AF);
  static const orange = Color(0xFFFF7A21);
  static const blue = Color(0xFF10A9FF);
  static const cyan = Color(0xFF2DD4FF);
  static const green = Color(0xFF42D392);
  static const red = Color(0xFFFF5E67);

  static const lightBg = Color(0xFFF4F6F8);
  static const lightPanel = Color(0xFFFDFEFF);
  static const lightPanel2 = Color(0xFFF0F3F6);
  static const lightBorder = Color(0xFFD7DEE5);
  static const lightText = Color(0xFF12202B);
  static const lightMuted = Color(0xFF65737E);
}

ThemeData buildGoViaTheme({Brightness brightness = Brightness.dark}) {
  final dark = brightness == Brightness.dark;
  final background = dark ? GoViaColors.bg : GoViaColors.lightBg;
  final panel = dark ? GoViaColors.panel : GoViaColors.lightPanel;
  final panel2 = dark ? GoViaColors.panel2 : GoViaColors.lightPanel2;
  final border = dark ? GoViaColors.border : GoViaColors.lightBorder;
  final text = dark ? GoViaColors.text : GoViaColors.lightText;

  final scheme = ColorScheme.fromSeed(
    seedColor: GoViaColors.orange,
    brightness: brightness,
    surface: panel,
  ).copyWith(
    primary: GoViaColors.orange,
    secondary: GoViaColors.blue,
    surface: panel,
    error: GoViaColors.red,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: border,
    cardColor: panel,
    textTheme: TextTheme(
      headlineLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: const TextStyle(fontWeight: FontWeight.w800),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: const TextStyle(height: 1.35),
      bodyMedium: const TextStyle(height: 1.35),
    ).apply(bodyColor: text, displayColor: text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GoViaColors.orange, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: panel,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF09131D) : const Color(0xFFFDFEFF),
      indicatorColor: const Color(0x332DD4FF),
      height: 68,
    ),
  );
}
