import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BsnlColors {
  static const navy = Color(0xFF0B3D91);
  static const navyDark = Color(0xFF072A66);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF5F6B7A);
  static const page = Color(0xFFF3F6FB);
  static const cymn = Color(0xFFBBDEFB);
  static const mnp = Color(0xFFFFE0B2);
  static const swap = Color(0xFFE1BEE7);
  static const postpaid = Color(0xFFFFF59D);
  static const issued = Color(0xFFC8E6C9);
}

ThemeData buildBsnlTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BsnlColors.navy,
      primary: BsnlColors.navy,
    ),
  );
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: BsnlColors.page,
    appBarTheme: AppBarTheme(
      backgroundColor: BsnlColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BsnlColors.navy,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
  );
}
