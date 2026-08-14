import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';

enum _ButtonVariant { filled, text, outlined }

/// The single button component used everywhere in the app — 45px height,
/// fully-rounded pill radius. Never use ElevatedButton/TextButton directly
/// in a screen.
///
/// Filled buttons default to the brand blue `context.appPrimary` with fixed
/// white text (2026-08-13, "copy primary color" — ported from the Smart
/// Feed Rwanda reference's `Button` primary variant, replacing the retired
/// black(light)/white(dark) theme-inversion rule). Leave `color` null to get
/// that behavior — only pass `color` for a deliberate semantic override
/// (e.g. a destructive action's warning color), in which case the
/// foreground is still auto-picked for contrast.
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
       underline = false,
       borderColor = null,
       backgroundColor = null;

  const CliniqnovvaButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.color,
    this.underline = false,
  }) : _variant = _ButtonVariant.text,
       borderColor = null,
       backgroundColor = null;

  /// White/page-background fill, a border, and `color`-tinted text — the
  /// "outline" look (2026-08-14, explicit user instruction, Branches
  /// screen's "+ Add Branch" specifically — not a default other call sites
  /// should reach for without the same instruction). Defaults match that
  /// request: text/icon in `context.appPrimary`, border in
  /// `context.appSecondaryBg`, background in `context.appBg` — override any
  /// of the three only for a deliberate different look.
  const CliniqnovvaButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.color,
    this.borderColor,
    this.backgroundColor,
  }) : _variant = _ButtonVariant.outlined,
       underline = false;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? color;
  final Color? borderColor;
  final Color? backgroundColor;
  final _ButtonVariant _variant;
  final bool underline;

  static const double _height = 45;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    final isDefaultPrimary = this.color == null;
    final color = this.color ?? context.appPrimary;
    final outlinedBorderColor = borderColor ?? context.appSecondaryBg;
    final outlinedBgColor = backgroundColor ?? context.appBg;

    // The default brand-blue fill always gets fixed white text (reference:
    // `--color-primary-contrast: #ffffff`, never auto-estimated) — only an
    // explicit custom `color` override falls back to auto-picked contrast.
    final onColor = isDefaultPrimary
        ? Colors.white
        : (ThemeData.estimateBrightnessForColor(color) == Brightness.light
              ? Colors.black
              : Colors.white);

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
      _ButtonVariant.outlined => SizedBox(
        height: _height,
        child: OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: outlinedBgColor,
            foregroundColor: color,
            disabledForegroundColor: color.withValues(alpha: 0.4),
            side: BorderSide(color: outlinedBorderColor, width: 1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
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
