import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_ext.dart';
import 'app_icon.dart';

enum _ButtonVariant { filled, outlined, text }

/// The single button component used everywhere in the app. Never use
/// `ElevatedButton`/`TextButton`/`OutlinedButton` directly in a screen — go
/// through [CliniqnovvaButton] (or its `.outlined`/`.text` constructors) so
/// changing button styling in one place updates every screen.
class CliniqnovvaButton extends StatelessWidget {
  const CliniqnovvaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
  }) : _variant = _ButtonVariant.filled;

  const CliniqnovvaButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
  }) : _variant = _ButtonVariant.outlined;

  const CliniqnovvaButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.textColor,
  }) : _variant = _ButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final IconRef? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final _ButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final effectiveOnPressed = disabled ? null : onPressed;

    Widget child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _variant == _ButtonVariant.filled
                  ? Colors.white
                  : (textColor ?? AppColors.primaryBlue),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                AppIcon(
                  icon!,
                  size: 18,
                  color: textColor ?? _defaultForegroundColor(context),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );

    final Widget button = switch (_variant) {
      _ButtonVariant.filled => ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primaryBlue,
          foregroundColor: textColor ?? Colors.white,
          disabledBackgroundColor: (backgroundColor ?? AppColors.primaryBlue)
              .withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: child,
      ),
      _ButtonVariant.outlined => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? context.appText,
          side: BorderSide(color: context.appBorder),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: child,
      ),
      _ButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
        ),
        child: child,
      ),
    };

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Color _defaultForegroundColor(BuildContext context) {
    return switch (_variant) {
      _ButtonVariant.filled => Colors.white,
      _ButtonVariant.outlined => context.appText,
      _ButtonVariant.text => AppColors.primaryBlue,
    };
  }
}
