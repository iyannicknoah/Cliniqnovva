import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_ext.dart';

/// Horizontally-scrolling next-N-days strip — Booking's date step (Part 21
/// Task 1) and Booking Detail's reschedule flow (Task 2) both use this.
class DateStripPicker extends StatelessWidget {
  const DateStripPicker({super.key, required this.selected, required this.onSelected, this.daysAhead = 14});

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final int daysAhead;

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: daysAhead,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = DateTime(today.year, today.month, today.day + index);
          final isSelected = _isSameDay(day, selected);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(day),
            child: Container(
              width: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? context.appPrimary : context.appSecondaryBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E().format(day),
                    style: TextStyle(
                      color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.appSubtext,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.appText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
