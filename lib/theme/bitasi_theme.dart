import 'package:flutter/material.dart';

/// BiTasi ana renk paleti ve ortak stiller.
class BiTasiColors {
  static const primaryRed = Color(0xFFE63946);
  // BiTaşı login brand color (requested): #B91924
  static const bitasiRed = Color(0xFFB91924);
  static const primaryBlue = Color(0xFF4A6DFF);
  static const secondaryWhite = Color(0xFFFFFFFF);
  static const textDarkGrey = Color(0xFF2B2D42);
  static const successGreen = Color(0xFF2A9D8F);
  static const warningOrange = Color(0xFFF4A261);
  static const errorRed = Color(0xFFE63946);
  static const backgroundGrey = Color(0xFFF8F9FA);
  static const borderGrey = Color(0xFFE5E7EB);
}

ThemeData buildBiTasiTheme() {
  return ThemeData(
    useMaterial3: true,
    primaryColor: BiTasiColors.primaryRed,
    scaffoldBackgroundColor: BiTasiColors.backgroundGrey,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BiTasiColors.primaryRed,
      primary: BiTasiColors.primaryRed,
      secondary: BiTasiColors.successGreen,
      surface: BiTasiColors.backgroundGrey,
      error: BiTasiColors.errorRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BiTasiColors.secondaryWhite,
      foregroundColor: BiTasiColors.textDarkGrey,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BiTasiColors.primaryRed,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: BiTasiColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: BiTasiColors.primaryRed, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.black.withAlpha(13),
      margin: const EdgeInsets.all(0),
    ),
  );
}
