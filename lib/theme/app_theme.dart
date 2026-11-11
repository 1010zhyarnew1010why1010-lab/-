// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color bgDarkNavy = Color(0xFF09101D);
  static const Color bgSecondaryNavy = Color(0xFF0D172A);
  static const Color cardSurface = Color(0xFF121E31);
  static const Color cardSurfaceLight = Color(0xFF17253D);

  // Gold Accents
  static const Color goldPrimary = Color(0xFFF6C358);
  static const Color goldDark = Color(0xFFC98B27);
  static const Color goldAccent = Color(0xFFF5B945);
  static const Color goldMuted = Color(0xFF9E7E38);
  static const Color goldBorder = Color(0x4DD4AF37); // ~30% opacity

  // Text colors
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF8E9BAE);
  static const Color textDark = Color(0xFF0A0F1D);

  // Status colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDarkNavy, bgSecondaryNavy],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6C358), Color(0xFFC98B27)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF132035), Color(0xFF0E1828)],
  );

  // ── Box Decorations ──────────────────────────────────────────────────────
  static BoxDecoration cardDecoration({
    double borderRadius = 16.0,
    Color? borderColor,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: cardSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? goldBorder,
        width: 1.2,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: goldPrimary.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  // ── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDarkNavy,
      fontFamily: 'NotoNaskhArabic',
      colorScheme: const ColorScheme.dark(
        primary: goldPrimary,
        secondary: goldAccent,
        surface: cardSurface,
        background: bgDarkNavy,
        onPrimary: textDark,
        onSurface: textWhite,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textWhite,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textWhite,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: goldBorder, width: 1.2),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: goldBorder, width: 1.2),
        ),
      ),
    );
  }
}
