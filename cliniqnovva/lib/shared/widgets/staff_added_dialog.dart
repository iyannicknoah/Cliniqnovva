import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import 'cliniqnovva_button.dart';

/// Shown right after a new staff account is created (2026-08-15, explicit
/// user spec, ported from a FlutterFlow component) — same "success" card as
/// [SuccessDialog] but with the generated login credentials in place of a
/// generic message, since the admin needs to read (and copy) them before
/// they're gone. Replaces the old plain `AlertDialog` in
/// `add_edit_staff_panel.dart`. Credential text is selectable so it can
/// still be copied during the 2-second auto-dismiss window.
Future<void> showStaffAddedDialog(
  BuildContext context, {
  required String email,
  required String password,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Staff added',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: StaffAddedDialog(email: email, password: password),
      ),
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

class StaffAddedDialog extends StatefulWidget {
  const StaffAddedDialog({
    super.key,
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  State<StaffAddedDialog> createState() => _StaffAddedDialogState();
}

class _StaffAddedDialogState extends State<StaffAddedDialog> {
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
    final credentialStyle = TextStyle(
      color: context.appSubtext,
      fontSize: 15,
      fontWeight: FontWeight.normal,
    );

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
                'Staff added',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 15),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    'Email: ${widget.email}',
                    textAlign: TextAlign.center,
                    style: credentialStyle,
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    'Password: ${widget.password}',
                    textAlign: TextAlign.center,
                    style: credentialStyle,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                'Share these credentials with them directly',
                textAlign: TextAlign.center,
                style: credentialStyle,
              ),
              const SizedBox(height: 15),
              Flexible(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: CliniqnovvaButton(
                      label: 'Continue',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
