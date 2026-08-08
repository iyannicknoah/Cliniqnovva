import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// A 1-5 star row for an average rating — rounds to the nearest whole star
/// (no half-star rendering; the underlying rating is still shown as a
/// decimal via [showValue] for precision). Used anywhere a branch's or
/// doctor's averageRating is displayed. Filled stars use `AppColors.skyBlue`,
/// matching the web dashboard's Reviews feature (see DESIGN_LANGUAGE.md —
/// star ratings there moved off amber to the system's second-primary accent
/// on 2026-07-25); this widget follows the same convention rather than
/// introducing amber back in for the Patient App.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = 16,
    this.showValue = true,
  });

  final double rating;
  final int? reviewCount;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: AppIcon(
              AppIcons.star,
              size: size,
              color: i < filled ? AppColors.skyBlue : context.appBorder,
            ),
          ),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            reviewCount != null ? '${rating.toStringAsFixed(1)} ($reviewCount)' : rating.toStringAsFixed(1),
            style: TextStyle(color: context.appSubtext, fontSize: size * 0.8, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
