import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';

/// A pill-shaped selectable option — department/service/doctor/date/slot
/// pickers across the booking flow (Part 21) all use this one shape:
/// filled `context.appPrimary` with inverse text when selected, neutral
/// `context.appSecondaryBg` otherwise. Same selected/unselected language as
/// Browse's filter chips (Part 20).
class BookingChip extends StatelessWidget {
  const BookingChip({super.key, required this.label, required this.isSelected, required this.onTap, this.subtitle});

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? context.appPrimary : context.appSecondaryBg;
    final fg = isSelected ? (context.isDark ? Colors.black : Colors.white) : context.appText;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
