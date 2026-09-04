import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BsnlColors {
  static const navy = Color(0xFF0A2A6B);
  static const navyDark = Color(0xFF071A44);
  static const royal = Color(0xFF1557C0);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF5B6573);
  static const page = Color(0xFFF3F0FF);
  static const paper = Color(0xFFFFFDF8);
  static const line = Color(0xFFE0D7F5);
  static const cymn = Color(0xFFD6E8FF);
  static const mnp = Color(0xFFFFE4C4);
  static const swap = Color(0xFFE8D5F2);
  static const postpaid = Color(0xFFFFF3B0);
  static const issued = Color(0xFFD4EDDA);
  static const gold = Color(0xFFF4A261);
  static const saffron = Color(0xFFE76F51);
  static const success = Color(0xFF1B7A4E);
}

ThemeData buildBsnlTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BsnlColors.navy,
      primary: BsnlColors.navy,
      surface: BsnlColors.paper,
    ),
  );
  final text = GoogleFonts.manropeTextTheme(base.textTheme).apply(
    bodyColor: BsnlColors.ink,
    displayColor: BsnlColors.ink,
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: BsnlColors.page,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: BsnlColors.navyDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BsnlColors.navy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BsnlColors.navy,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BsnlColors.paper,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BsnlColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BsnlColors.royal, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    cardTheme: CardThemeData(
      color: BsnlColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BsnlColors.line),
      ),
    ),
    dividerColor: BsnlColors.line,
  );
}

BoxDecoration bsnlPageGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF7F3FF),
        Color(0xFFE8F4FF),
        Color(0xFFFFF3E8),
      ],
    ),
  );
}
