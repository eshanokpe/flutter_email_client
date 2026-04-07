import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors — light palette
  static const Color primary = Color(0xFFFFFFFF); // page background
  static const Color secondary = Color(0xFFF6F8FC); // drawer / secondary bg
  static const Color surface = Color(0xFFF1F4F9); // cards / input fills
  static const Color surfaceVariant = Color(0xFFE8EDF5); // chips / tags
  static const Color highlight = Color(0xFFD93025); // accent red (Gmail-ish)
  static const Color accent = Color(0xFF1A73E8); // links / secondary accent
  static const Color onSurface = Color(0xFF1F1F1F); // primary text
  static const Color onSurfaceMuted = Color(0xFF6B7280); // secondary text
  static const Color divider = Color(0xFFE5E9F0); // dividers / borders
  static const Color unreadDot = Color(0xFF1A73E8); // unread indicator
  static const Color successGreen = Color(0xFF188038); // success states
  static const Color warningAmber = Color(0xFFF29900); // warnings / stars
  static const Color errorRed = Color(0xFFD93025); // errors

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: primary,
      colorScheme: const ColorScheme.light(
        primary: highlight,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onSurface,
        error: errorRed,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme)
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
        scrolledUnderElevation: 0.5,
        shadowColor: divider,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        iconTheme: const IconThemeData(color: onSurface),
        surfaceTintColor: Colors.transparent,
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
          borderSide: const BorderSide(color: accent, width: 2),
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
        color: primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      drawerTheme: const DrawerThemeData(
        backgroundColor: secondary,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
