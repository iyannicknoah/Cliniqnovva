import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder screen (Part 1 — Project Foundation). Real content lands in
/// a later part of the build plan.
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Patient Profile',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (id != null) ...[
              const SizedBox(height: 8),
              Text('id: $id', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
