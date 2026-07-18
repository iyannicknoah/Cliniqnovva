import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder screen (Part 1 — Project Foundation). Real content lands in
/// a later part of the build plan.
class OversightScreen extends StatelessWidget {
  const OversightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundTint,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Platform Oversight',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
