import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// A compact "★ 4.8" pill — the Home/Browse card's overlay badge on the
/// clinic image (distinct from [RatingStars]' 5-star row, which is too busy
/// for a small image overlay). Hidden entirely when there's nothing to
/// show yet (no reviews). Translucent-white blurred pill + amber star +
/// dark text — matches the reference design exactly (not the app's usual
/// skyBlue accent: this badge sits on a photo, not a themed surface, so it
/// intentionally uses its own fixed light/dark pair rather than
/// `context.appXxx` tokens).
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, required this.reviewCount});

  static const _amberStar = Color(0xFFFFBF09);
  static const _darkText = Color(0xFF14181B);

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xA2FFFFFF),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(AppIcons.star, size: 18, color: _amberStar),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(color: _darkText, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
