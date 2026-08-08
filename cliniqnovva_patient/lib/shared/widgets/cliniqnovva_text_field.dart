import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';

/// The single text field component used everywhere — identical to
/// cliniqnovva/lib/shared/widgets/cliniqnovva_text_field.dart.
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
    this.prefixIcon,
    this.maxLines = 1,
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
  final Widget? prefixIcon;

  /// Part 24 — Leave Review's comment fields need more than one line.
  /// Defaults to 1 (every existing call site is unaffected).
  final int maxLines;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.inputRadius),
    borderSide: BorderSide(color: color, width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onFieldSubmitted,
          maxLines: maxLines,
          style: TextStyle(color: context.appText, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            errorText: errorText,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: context.appCard,
            contentPadding: const EdgeInsetsDirectional.fromSTEB(
              14,
              15,
              15,
              15,
            ),
            border: _border(context.appBorder),
            enabledBorder: _border(context.appBorder),
            focusedBorder: _border(context.appPrimary),
            errorBorder: _border(AppColors.errorRed),
            focusedErrorBorder: _border(AppColors.errorRed),
          ),
        ),
      ],
    );
  }
}
