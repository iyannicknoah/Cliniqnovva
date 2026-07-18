import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'cliniqnovva_colors.dart';

/// The two `ThemeData` instances every Cliniqnovva app (patient_app,
/// staff_app) should pass to `MaterialApp(theme: ..., darkTheme: ...)`.
/// This is the one place base Material styling (color scheme, typography)
/// lives — change it here, both apps update.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CliniqnovvaColors.light.appBg,
      fontFamily: 'Roboto',
      extensions: const [CliniqnovvaColors.light],
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CliniqnovvaColors.dark.appBg,
      fontFamily: 'Roboto',
      extensions: const [CliniqnovvaColors.dark],
    );
  }
}
