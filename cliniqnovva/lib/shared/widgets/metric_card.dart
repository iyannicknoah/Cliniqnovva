import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'cliniqnovva_card.dart';

/// The single KPI/stat-tile component for dashboards — a bordered-18 box
/// with a secondaryText label above a bold value (18, w600), matching the
/// reference design language's stat card exactly.
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
