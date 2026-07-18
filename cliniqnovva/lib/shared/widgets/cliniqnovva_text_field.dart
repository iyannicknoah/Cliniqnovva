import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The single text field component used everywhere — label above the field,
/// #F6FAFA background, 0.5px #D8E8E6 border, primaryTeal focus glow, 44px
/// height, 10px radius.
class CliniqnovvaTextField extends StatelessWidget {
  const CliniqnovvaTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;

  static const _borderColor = Color(0xFFD8E8E6);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onSubmitted: onFieldSubmitted,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: AppColors.backgroundTint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: const BorderSide(color: _borderColor, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: const BorderSide(color: _borderColor, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: const BorderSide(color: AppColors.errorRed, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
