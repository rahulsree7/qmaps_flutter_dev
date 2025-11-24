import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modern Color Palette
  static const Color primaryBlue = Color(0xFF3B82F6); // Bright Blue
  static const Color primaryPurple = Color(0xFF8B5CF6); // Violet
  static const Color darkPurple = Color(0xFF6D28D9); // Dark Violet
  static const Color accentTeal = Color(0xFF10B981); // Emerald
  static const Color accentOrange = Color(0xFFF59E0B); // Amber
  static const Color accentRed = Color(0xFFEF4444); // Red
  static const Color primaryRed = Color(0xFFDC2626); // Primary Red
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], // Indigo to Violet
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Neutral colors
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color lightBackground = Color(0xFFF1F5F9); // Slate 100
  static const Color cardBackground = Colors.white;
  static const Color surfaceColor = Color(0xFFF8FAFC); // Slate 50
  
  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Priority colors
  static const Color highPriority = Color(0xFFF44336);
  static const Color mediumPriority = Color(0xFFFF9800);
  static const Color lowPriority = Color(0xFF4CAF50);

  // Inter Font - Similar to San Francisco, available on all platforms via google_fonts
  // Helper to create TextStyle with Inter font
  static TextStyle _textStyleWithFont({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        secondary: primaryPurple,
        surface: cardBackground,
        background: lightBackground,
        onPrimary: textLight,
        onSecondary: textLight,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: _textStyleWithFont(fontSize: 57, fontWeight: FontWeight.w400, color: textPrimary),
        displayMedium: _textStyleWithFont(fontSize: 45, fontWeight: FontWeight.w400, color: textPrimary),
        displaySmall: _textStyleWithFont(fontSize: 36, fontWeight: FontWeight.w400, color: textPrimary),
        headlineLarge: _textStyleWithFont(fontSize: 32, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: _textStyleWithFont(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: _textStyleWithFont(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: _textStyleWithFont(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: _textStyleWithFont(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        titleSmall: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: _textStyleWithFont(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: _textStyleWithFont(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        labelMedium: _textStyleWithFont(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
        labelSmall: _textStyleWithFont(fontSize: 11, fontWeight: FontWeight.w500, color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textStyleWithFont(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: textLight,
          elevation: 4,
          shadowColor: primaryRed.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryPurple.withOpacity(0.2),
        labelStyle: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: primaryPurple,
        surface: Color(0xFF1E1E1E),
        background: darkBackground,
        onPrimary: textLight,
        onSecondary: textLight,
        onSurface: textLight,
        onBackground: textLight,
      ),
      textTheme: TextTheme(
        displayLarge: _textStyleWithFont(fontSize: 57, fontWeight: FontWeight.w400, color: textLight),
        displayMedium: _textStyleWithFont(fontSize: 45, fontWeight: FontWeight.w400, color: textLight),
        displaySmall: _textStyleWithFont(fontSize: 36, fontWeight: FontWeight.w400, color: textLight),
        headlineLarge: _textStyleWithFont(fontSize: 32, fontWeight: FontWeight.w600, color: textLight),
        headlineMedium: _textStyleWithFont(fontSize: 28, fontWeight: FontWeight.w600, color: textLight),
        headlineSmall: _textStyleWithFont(fontSize: 24, fontWeight: FontWeight.w600, color: textLight),
        titleLarge: _textStyleWithFont(fontSize: 22, fontWeight: FontWeight.w600, color: textLight),
        titleMedium: _textStyleWithFont(fontSize: 16, fontWeight: FontWeight.w500, color: textLight),
        titleSmall: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w500, color: textLight),
        bodyLarge: _textStyleWithFont(fontSize: 16, fontWeight: FontWeight.w400, color: textLight),
        bodyMedium: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w400, color: textLight),
        bodySmall: _textStyleWithFont(fontSize: 12, fontWeight: FontWeight.w400, color: textLight),
        labelLarge: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w500, color: textLight),
        labelMedium: _textStyleWithFont(fontSize: 12, fontWeight: FontWeight.w500, color: textLight),
        labelSmall: _textStyleWithFont(fontSize: 11, fontWeight: FontWeight.w500, color: textLight),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textStyleWithFont(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: textLight,
          elevation: 4,
          shadowColor: primaryRed.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPurple,
          side: const BorderSide(color: primaryPurple, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        selectedColor: primaryPurple.withOpacity(0.2),
        labelStyle: _textStyleWithFont(fontSize: 14, fontWeight: FontWeight.w400, color: textLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // Custom gradient decorations
  static BoxDecoration get primaryGradientDecoration {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [primaryRed, Color(0xFFE64A19)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: primaryRed.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration get secondaryGradient {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [primaryPurple, darkPurple],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: primaryPurple.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Text styles with Inter font
  static TextStyle get heading1 => _textStyleWithFont(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static TextStyle get heading2 => _textStyleWithFont(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get heading3 => _textStyleWithFont(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get bodyLarge => _textStyleWithFont(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle get bodyMedium => _textStyleWithFont(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static TextStyle get bodySmall => _textStyleWithFont(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
}
