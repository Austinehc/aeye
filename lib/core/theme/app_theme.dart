import 'package:flutter/material.dart';

class AppTheme {
  // High contrast colors for accessibility
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFFFF9800);
  static const Color backgroundColor = Color(0xFF000000);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color textColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color successColor = Color(0xFF4CAF50);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: textColor,
        onSecondary: textColor,
        onSurface: textColor,
        onError: textColor,
      ),
      
      // High contrast for accessibility - Reduced sizes to prevent overflow
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 26,  // Reduced from 32
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        displayMedium: TextStyle(
          fontSize: 22,  // Reduced from 28
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,  // Reduced from 24
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 17,  // Reduced from 20
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        headlineSmall: TextStyle(
          fontSize: 15,  // Added for smaller headings
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,  // Reduced from 18
          color: textColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,  // Reduced from 16
          color: textColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,  // Added for smaller text
          color: textColor,
        ),
      ),
      
      // Large touch targets for accessibility - Reduced to fit viewport
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(180, 56),  // Reduced from 200x70
          backgroundColor: primaryColor,
          foregroundColor: textColor,
          textStyle: const TextStyle(
            fontSize: 16,  // Reduced from 20
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      iconTheme: const IconThemeData(
        size: 40,
        color: textColor,
      ),
      
      cardTheme: const CardThemeData(
        color: surfaceColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
    );
  }
}