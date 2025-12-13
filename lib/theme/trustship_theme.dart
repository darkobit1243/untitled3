import 'package:flutter/material.dart';

/// TrustShip ana renk paleti ve ortak stiller.
class TrustShipColors {
  static const primaryRed = Color(0xFFE63946);
  static const primaryBlue = Color(0xFF4A6DFF);
  static const secondaryWhite = Color(0xFFFFFFFF);
  static const textDarkGrey = Color(0xFF2B2D42);
  static const successGreen = Color(0xFF2A9D8F);
  static const warningOrange = Color(0xFFF4A261);
  static const errorRed = Color(0xFFE63946);
  static const backgroundGrey = Color(0xFFF8F9FA);
  static const borderGrey = Color(0xFFE5E7EB);
}

ThemeData buildTrustShipTheme() {
  return ThemeData(
    useMaterial3: true,
    primaryColor: TrustShipColors.primaryRed,
    scaffoldBackgroundColor: TrustShipColors.backgroundGrey,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TrustShipColors.primaryRed,
      primary: TrustShipColors.primaryRed,
      secondary: TrustShipColors.successGreen,
      background: TrustShipColors.backgroundGrey,
      error: TrustShipColors.errorRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: TrustShipColors.secondaryWhite,
      foregroundColor: TrustShipColors.textDarkGrey,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TrustShipColors.primaryRed,
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
        borderSide: const BorderSide(color: TrustShipColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TrustShipColors.primaryRed, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.black.withOpacity(0.05),
      margin: const EdgeInsets.all(0),
    ),
  );
}


