import 'package:flutter/material.dart';

/// Central design tokens for SafeHer, matching the Figma design
/// (soft pink background, purple/magenta accents, red SOS, green safe state).
class AppColors {
  static const purple = Color(0xFF9B3FE8);
  static const purple2 = Color(0xFF7A1FC9);
  static const magenta = Color(0xFFE0189A);
  static const pink = Color(0xFFFBE4F5);
  static const pink2 = Color(0xFFF5C9EA);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF22C55E);
  static const textDark = Color(0xFF241428);
  static const muted = Color(0xFF8A7A92);
}

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  void applySettings(Map<String, dynamic> settings) {
    final dark = settings['autoNightMode'] == true;
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.pink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.pink2.withValues(alpha: .6)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF171018),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1620),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3A2C40)),
        ),
      ),
    );
  }
}
