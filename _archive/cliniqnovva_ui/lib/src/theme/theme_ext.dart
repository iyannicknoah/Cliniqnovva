import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'cliniqnovva_colors.dart';

/// The single way screens/widgets should read design-system colors:
/// `context.appBg`, `context.appCard`, `context.cardDeco()`, etc. — never
/// read [CliniqnovvaColors] or raw hex values directly from a screen.
extension CliniqnovvaThemeX on BuildContext {
  CliniqnovvaColors get _colors {
    final ext = Theme.of(this).extension<CliniqnovvaColors>();
    assert(
      ext != null,
      'CliniqnovvaColors extension is missing — make sure the app theme was '
      'built with AppTheme.light()/AppTheme.dark() from cliniqnovva_ui.',
    );
    return ext ?? CliniqnovvaColors.light;
  }

  Color get appBg => _colors.appBg;
  Color get appText => _colors.appText;
  Color get appSubtext => _colors.appSubtext;
  Color get appCard => _colors.appCard;
  Color get appBorder => _colors.appBorder;
  Color get appTint => _colors.appTint;

  Color get pillGreenBg => _colors.pillGreenBg;
  Color get pillGreenText => _colors.pillGreenText;
  Color get pillRedBg => _colors.pillRedBg;
  Color get pillRedText => _colors.pillRedText;
  Color get pillAmberBg => _colors.pillAmberBg;
  Color get pillAmberText => _colors.pillAmberText;
  Color get pillNavyBg => _colors.pillNavyBg;
  Color get pillNavyText => _colors.pillNavyText;
  Color get pillBlueBg => _colors.pillBlueBg;
  Color get pillBlueText => _colors.pillBlueText;

  /// The standard card container look used across the whole app — change it
  /// here and every card (KPI tiles, list rows, panels) updates everywhere.
  BoxDecoration cardDeco({double radius = AppRadius.lg}) {
    return BoxDecoration(
      color: appCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: appBorder),
    );
  }
}
