import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder screen (Part 1 — Project Foundation). Real content lands in
/// a later part of the build plan.
class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({super.key, this.invoiceId});

  final String? invoiceId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundTint,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Invoice Detail',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (invoiceId != null) ...[
              const SizedBox(height: 8),
              Text('invoiceId: $invoiceId', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
