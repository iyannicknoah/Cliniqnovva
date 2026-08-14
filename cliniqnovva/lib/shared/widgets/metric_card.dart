import 'package:flutter/material.dart';

import '../../core/theme/theme_ext.dart';
import 'cliniqnovva_card.dart';

/// The single KPI/stat-tile component for dashboards — a bordered-18 box
/// with a bold value (18, w600) followed by a secondaryText label
/// underneath (2026-08-14, explicit user instruction — "label text come
/// after the real value"; was label-above-value, matching the HRNova
/// reference stat card, 2026-07-23).
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
          Text(
            value,
            style: TextStyle(
              color: context.appText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: context.appSubtext)),
        ],
      ),
    );
  }
}
