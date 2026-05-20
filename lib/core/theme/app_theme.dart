import 'package:flutter/material.dart';

/// Rayuela brand palette, pulled from the web app's Vuetify config and CSS
/// (primary green, accent colors for leaderboard states).
class RayuelaColors {
  const RayuelaColors._();

  static const Color primary = Color(0xFF4DBA87); // PWA theme color
  static const Color primaryDark = Color(0xFF3A9B6E);
  static const Color accent = Color(0xFF319FD3);
  static const Color success = Color(0xFF27AE60);
  static const Color danger = Color(0xFFC0392B);
  static const Color warning = Color(0xFFE67E22);
  static const Color neutral = Color(0xFF90A4AE);
  static const Color surface = Color(0xFFF7F9F8);
  static const Color onSurface = Color(0xFF1B2B26);
}

/// Theme extension for the Check-in Wizard UI.
@immutable
class RayuelaWizardColors extends ThemeExtension<RayuelaWizardColors> {
  const RayuelaWizardColors({
    required this.wizardProgress,
    required this.wizardBackground,
    required this.wizardStepText,
  });

  final Color? wizardProgress;
  final Color? wizardBackground;
  final Color? wizardStepText;

  @override
  RayuelaWizardColors copyWith({
    Color? wizardProgress,
    Color? wizardBackground,
    Color? wizardStepText,
  }) {
    return RayuelaWizardColors(
      wizardProgress: wizardProgress ?? this.wizardProgress,
      wizardBackground: wizardBackground ?? this.wizardBackground,
      wizardStepText: wizardStepText ?? this.wizardStepText,
    );
  }

  @override
  RayuelaWizardColors lerp(
    ThemeExtension<RayuelaWizardColors>? other,
    double t,
  ) {
    if (other is! RayuelaWizardColors) {
      return this;
    }
    return RayuelaWizardColors(
      wizardProgress: Color.lerp(wizardProgress, other.wizardProgress, t),
      wizardBackground: Color.lerp(wizardBackground, other.wizardBackground, t),
      wizardStepText: Color.lerp(wizardStepText, other.wizardStepText, t),
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RayuelaColors.primary,
      surface: RayuelaColors.surface,
      error: RayuelaColors.danger,
    );
    return _build(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RayuelaColors.primary,
      brightness: Brightness.dark,
      error: RayuelaColors.danger,
    );
    return _build(colorScheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      extensions: [
        const RayuelaWizardColors(
          wizardProgress: Color(0xFF4DBA87),
          wizardBackground: Color(0xFF1E3A2F),
          wizardStepText: Color(0xFFF5EDD6),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide.none,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
