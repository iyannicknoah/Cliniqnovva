import 'package:flutter/material.dart';

import '../../core/theme/theme_ext.dart';

/// The single segmented-tab control — `appSecondaryBg` track, `appCard`
/// selected pill (same shape as the sidebar's Light/Dark theme toggle).
/// Used instead of Material's default `TabBar` so tab rows never need
/// their own indicator-color override to satisfy the "no primary color"
/// rule. First promoted here from Patient Profile's Profile/Medical
/// Records/Documents tabs (Part 9); reused by Appointments' Today/
/// Upcoming/History tabs (Part 11).
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appSecondaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? context.appCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
