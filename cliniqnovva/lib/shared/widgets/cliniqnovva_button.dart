import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum _ButtonVariant { filled, text }

/// The single button component used everywhere in the app — 45px height,
/// fully-rounded pill radius. Never use ElevatedButton/TextButton directly
/// in a screen.
///
/// Filled buttons are theme-inverted by design (explicit instruction,
/// 2026-07-19): black with white text in light mode, white with black text
/// in dark mode. Leave `color` null to get that behavior.
///
/// `.text()` is the transparent, underline-capable secondary style (e.g.
/// "Forgot password?", "Sign up").
class CliniqnovvaButton extends StatelessWidget {
  const CliniqnovvaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.color,
  }) : _variant = _ButtonVariant.filled,
       underline = false;

  const CliniqnovvaButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.color = AppColors.textPrimary,
    this.underline = false,
  }) : _variant = _ButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? color;
  final _ButtonVariant _variant;
  final bool underline;

  static const double _height = 45;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = this.color ?? (isDark ? Colors.white : Colors.black);

    // Auto-pick a readable foreground for whatever the background resolves
    // to: black text on light fills, white text on dark fills.
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? Colors.black
        : Colors.white;

    final Widget button = switch (_variant) {
      _ButtonVariant.filled => SizedBox(
        height: _height,
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: onColor,
            disabledBackgroundColor: color.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onColor,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
      _ButtonVariant.text => TextButton(
        onPressed: disabled ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: underline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
      ),
    };

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
