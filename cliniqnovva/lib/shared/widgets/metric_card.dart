import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'cliniqnovva_card.dart';

/// The single KPI/metric-tile component for dashboards — big bold value,
/// small uppercase label, icon in a colored circle, optional trend text.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.trend,
    this.color = AppColors.primaryTeal,
  });

  final String value;
  final String label;
  final IconData icon;
  final String? trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.pillGreenBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    trend!,
                    style: const TextStyle(color: AppColors.pillGreenText, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
