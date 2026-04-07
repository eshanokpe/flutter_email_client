import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF1A1A2E);
  static const Color secondary = Color(0xFF16213E);
  static const Color accent = Color(0xFF0F3460);
  static const Color highlight = Color(0xFFE94560);
  static const Color surface = Color(0xFF1F2B47);
  static const Color surfaceVariant = Color(0xFF253152);
  static const Color onSurface = Color(0xFFF0F2F5);
  static const Color onSurfaceMuted = Color(0xFF8A9CC2);
  static const Color divider = Color(0xFF2A3A5C);
  static const Color unreadDot = Color(0xFF4FC3F7);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color errorRed = Color(0xFFE94560);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: highlight,
        secondary: unreadDot,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onSurface,
        error: errorRed,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.dmSans(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: onSurface,
              letterSpacing: -0.5,
            ),
            displayMedium: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
            titleLarge: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
            titleMedium: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: onSurface,
            ),
            bodyLarge: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: onSurface,
            ),
            bodyMedium: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: onSurfaceMuted,
            ),
            labelLarge: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: onSurface,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        iconTheme: const IconThemeData(color: onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: highlight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        hintStyle: GoogleFonts.dmSans(color: onSurfaceMuted, fontSize: 14),
        labelStyle: GoogleFonts.dmSans(color: onSurfaceMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highlight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: GoogleFonts.dmSans(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
