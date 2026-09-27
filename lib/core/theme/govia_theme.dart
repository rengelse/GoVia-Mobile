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
}

ThemeData buildGoViaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: GoViaColors.orange,
    brightness: Brightness.dark,
    surface: GoViaColors.panel,
  ).copyWith(
    primary: GoViaColors.orange,
    secondary: GoViaColors.blue,
    surface: GoViaColors.panel,
    error: GoViaColors.red,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: GoViaColors.bg,
    dividerColor: GoViaColors.border,
    cardColor: GoViaColors.panel,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(height: 1.35),
      bodyMedium: TextStyle(height: 1.35),
    ).apply(bodyColor: GoViaColors.text, displayColor: GoViaColors.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GoViaColors.panel2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GoViaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GoViaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GoViaColors.orange, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: GoViaColors.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: GoViaColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF09131D),
      indicatorColor: Color(0x332DD4FF),
      height: 72,
    ),
  );
}
