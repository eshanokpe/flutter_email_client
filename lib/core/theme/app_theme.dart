import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Gmail exact colors
  static const Color gmailRed = Color(0xFFEA4335);
  static const Color gmailBlue = Color(0xFF1A73E8);
  static const Color gmailGreen = Color(0xFF34A853);
  static const Color gmailYellow = Color(0xFFFBBC05);

  static const Color primary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFF6F8FC); // drawer bg
  static const Color surface = Color(0xFFF1F3F4); // search bar / chips
  static const Color surfaceVariant = Color(0xFFE8EAED);
  static const Color highlight = gmailRed;
  static const Color accent = gmailBlue;
  static const Color onSurface = Color(0xFF202124); // Gmail body text
  static const Color onSurfaceMuted = Color(0xFF5F6368); // Gmail secondary text
  static const Color divider = Color(0xFFE0E0E0);
  static const Color unreadDot = gmailBlue;
  static const Color unreadBg = Color(0xFFF2F6FC); // unread row tint
  static const Color successGreen = gmailGreen;
  static const Color warningAmber = gmailYellow;
  static const Color errorRed = gmailRed;
  static const Color starColor = Color(0xFFF4B400); // Gmail star gold

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: primary,
      colorScheme: const ColorScheme.light(
        primary: gmailBlue,
        secondary: gmailRed,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onSurface,
        error: errorRed,
      ),
      textTheme:
          GoogleFonts.robotoTextTheme(
            // Gmail uses Roboto
            ThemeData.light().textTheme,
          ).copyWith(
            titleLarge: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: onSurface,
            ),
            titleMedium: GoogleFonts.roboto(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: onSurface,
            ),
            bodyLarge: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: onSurface,
            ),
            bodyMedium: GoogleFonts.roboto(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: onSurfaceMuted,
            ),
            labelLarge: GoogleFonts.roboto(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: onSurface,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: divider,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        iconTheme: const IconThemeData(color: onSurfaceMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gmailBlue, width: 2),
        ),
        hintStyle: GoogleFonts.roboto(color: onSurfaceMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gmailBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: primary,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      drawerTheme: const DrawerThemeData(
        backgroundColor: secondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onSurface,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF323232),
        contentTextStyle: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: const Color(0xFFD3E3FD),
        labelStyle: GoogleFonts.roboto(fontSize: 13, color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
    );
  }
}
