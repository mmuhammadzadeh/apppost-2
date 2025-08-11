import 'package:flutter/material.dart';

class AppTheme {
  // Dark theme colors
  static const Color primaryDark = Color(0xFF1A1A1A);
  static const Color secondaryDark = Color(0xFF2D2D2D);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color backgroundDark = Color(0xFF0F0F0F);

  // Golden yellow colors
  static const Color primaryGold = Color(0xFFFFD700);
  static const Color secondaryGold = Color(0xFFFFA500);
  static const Color accentGold = Color(0xFFFF8C00);
  static const Color lightGold = Color(0xFFFFF8DC);

  // Accent colors
  static const Color blueAccent = Color(0xFF4FC3F7);
  static const Color greenAccent = Color(0xFF4CAF50);
  static const Color redAccent = Color(0xFFF44336);
  static const Color purpleAccent = Color(0xFF9C27B0);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textHint = Color(0xFF666666);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: secondaryGold,
        surface: surfaceDark,
        background: backgroundDark,
        onPrimary: Color(0xFF000000),
        onSecondary: Color(0xFF000000),
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),

      // Scaffold
      scaffoldBackgroundColor: backgroundDark,

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: primaryGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primaryGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primaryGold),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 8,
        shadowColor: primaryGold.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          elevation: 6,
          shadowColor: primaryGold.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGold.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: redAccent, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
        prefixIconColor: primaryGold,
        suffixIconColor: primaryGold,
      ),

      // Tab bar theme
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryGold,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryGold,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: primaryGold, size: 24),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: textHint, fontSize: 12),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: textHint,
        thickness: 1,
        space: 1,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceDark,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        elevation: 16,
        shadowColor: primaryGold.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: primaryGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 16),
      ),

      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        modalBackgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGold,
        foregroundColor: Colors.black,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: secondaryDark,
        selectedColor: primaryGold,
        disabledColor: textHint,
        labelStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryGold;
          }
          return textSecondary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryGold.withOpacity(0.5);
          }
          return textHint.withOpacity(0.3);
        }),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryGold;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryGold;
          }
          return textSecondary;
        }),
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryGold,
        inactiveTrackColor: textHint.withOpacity(0.3),
        thumbColor: primaryGold,
        overlayColor: primaryGold.withOpacity(0.2),
        valueIndicatorColor: primaryGold,
        valueIndicatorTextStyle: const TextStyle(color: Colors.black),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGold,
        linearTrackColor: textHint,
        circularTrackColor: textHint,
      ),
    );
  }

  // Custom gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGold, secondaryGold],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, secondaryDark],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceDark, secondaryDark],
  );

  // Custom shadows
  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primaryGold.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryGold.withOpacity(0.4),
      blurRadius: 12,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  // Custom animations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // Custom curves
  static const Curve primaryCurve = Curves.easeInOutCubic;
  static const Curve secondaryCurve = Curves.easeOutBack;
  static const Curve bounceCurve = Curves.elasticOut;
}
