import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';

/// The single text field component used everywhere — label above the field,
/// fill matches the page/card background (no separate tint), 1px border
/// (alternate/focused/error states), 12px radius, isDense layout.
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

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.inputRadius),
    borderSide: BorderSide(color: color, width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onFieldSubmitted,
          style: TextStyle(color: context.appText, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            errorText: errorText,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: context.appCard,
            contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 15, 15, 15),
            border: _border(context.appBorder),
            enabledBorder: _border(context.appBorder),
            focusedBorder: _border(AppColors.primary),
            errorBorder: _border(AppColors.errorRed),
            focusedErrorBorder: _border(AppColors.errorRed),
          ),
        ),
      ],
    );
  }
}
