import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';

/// Shows the standard "action succeeded" popup (2026-08-15, explicit user
/// spec, ported from a FlutterFlow component) — a centered card with a
/// primary-colored check mark, a title, and a message. No dismiss button
/// (explicit instruction, 2026-08-15) — it auto-dismisses after 2 seconds,
/// full stop.
///
/// Reserved for major create/save forms (Add Clinic, Add Branch, Add
/// Service, Add Department, staff edits, inventory items, patient profile
/// saves) — quick inline actions (status toggles, replies, payments) keep
/// the SnackBar from `runWithFeedback`.
Future<void> showSuccessDialog(
  BuildContext context, {
  String title = 'Success!',
  required String message,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Success',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Material(
      type: MaterialType.transparency,
      child: Center(child: SuccessDialog(title: title, message: message)),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class SuccessDialog extends StatefulWidget {
  const SuccessDialog({super.key, this.title = 'Success!', required this.message});

  final String title;
  final String message;

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        height: 400,
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: context.appSecondaryBg),
                ),
                child: Icon(Icons.check, color: context.appPrimary, size: 44),
              ),
              const SizedBox(height: 15),
              Text(
                widget.title,
                style: TextStyle(
                  color: context.appText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.appSubtext,
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
