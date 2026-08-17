import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';

/// Shared rendering pieces for anywhere a review/rating shows up — the
/// Reviews page (`reviews_screen.dart`) and the Dashboard's Reviews card
/// both use these (2026-07-25, pulled out so the Dashboard preview can look
/// identical to the real page instead of drifting from it).

/// Filled/outline star row — sky blue for filled stars everywhere reviews
/// appear (explicit instruction, was `AppColors.pillAmberText`/amber).
class ReviewStarRow extends StatelessWidget {
  const ReviewStarRow({super.key, required this.rating, this.size = 14});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => AppIcon(
          AppIcons.star,
          size: size,
          color: i < rating ? AppColors.skyBlue : context.appBorder,
        ),
      ),
    );
  }
}

/// One star icon + a single-decimal numeric rating (e.g. "★ 4.0") — a
/// compact alternative to [ReviewStarRow]'s 5-icon row for places like a
/// name line where 5 stars would crowd the layout.
class ReviewSingleStarRating extends StatelessWidget {
  const ReviewSingleStarRating({super.key, required this.rating, this.size = 14});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(AppIcons.star, size: size, color: AppColors.skyBlue),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(color: context.appSubtext, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// A single row of the 5/4/3/2/1 rating-distribution bars — sky blue fill,
/// light track (same color as [ReviewStarRow]'s filled stars).
class ReviewDistributionRow extends StatelessWidget {
  const ReviewDistributionRow({super.key, required this.stars, required this.count, required this.maxCount});

  final int stars;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: Text('$stars', style: TextStyle(color: context.appSubtext, fontSize: 12.5)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(
                    height: 6,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: context.appSecondaryBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: AppColors.skyBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The big-number/count/stars + distribution-bars header — a `CliniqnovvaCard`
/// on its own (Reviews page) or embedded as plain content inside another
/// card (Dashboard preview, via [asCard]: false).
class RatingSummaryHeader extends StatelessWidget {
  const RatingSummaryHeader({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    required this.distribution,
    this.asCard = true,
  });

  final double averageRating;
  final int ratingCount;
  final Map<int, int> distribution;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final maxCount = distribution.values.isEmpty ? 0 : distribution.values.reduce((a, b) => a > b ? a : b);

    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: TextStyle(color: context.appText, fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                ratingCount >= 1000
                    ? '${(ratingCount / 1000).toStringAsFixed(1)}K ratings'
                    : '$ratingCount rating${ratingCount == 1 ? '' : 's'}',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ReviewStarRow(rating: averageRating.round(), size: 18),
            ],
          ),
          const SizedBox(width: 24),
          VerticalDivider(width: 1, thickness: 1, color: context.appSecondaryBg),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final stars in [5, 4, 3, 2, 1])
                  ReviewDistributionRow(stars: stars, count: distribution[stars] ?? 0, maxCount: maxCount),
              ],
            ),
          ),
        ],
      ),
    );

    return asCard ? CliniqnovvaCard(child: content) : content;
  }
}

/// Sample data (2026-07-25) — shown only when a branch has zero reviews yet,
/// so the design can be previewed without waiting for real reviews. Clearly
/// labeled wherever it renders; never mixed with real review data.
const sampleAverageRating = 4.8;
const sampleRatingCount = 1100;
const sampleDistribution = {5: 700, 4: 280, 3: 80, 2: 30, 1: 10};
const sampleReviewCards = [
  (name: 'Alex Turner', rating: 4, comment: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. In egestas mi a commodo rhoncus.'),
  (name: 'Chantal K.', rating: 5, comment: 'The staff were friendly and the whole visit felt well organized from start to finish.'),
  (name: 'Didier R.', rating: 4, comment: 'Quick appointment booking and the doctor took time to explain the diagnosis clearly.'),
];

/// A simple comment-first review card: comment text, then stars + name +
/// relative time below — matches the reference screenshot. Used for sample
/// rows (no real review behind them) and for the Dashboard's compact
/// preview list.
class SimpleReviewCard extends StatelessWidget {
  const SimpleReviewCard({
    super.key,
    required this.comment,
    required this.rating,
    required this.name,
    required this.timeLabel,
  });

  final String comment;
  final int rating;
  final String name;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment, style: TextStyle(color: context.appText, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              ReviewStarRow(rating: rating),
              const SizedBox(width: 10),
              Text(name, style: TextStyle(color: context.appSubtext, fontSize: 12.5, fontWeight: FontWeight.w600)),
              Text(' · $timeLabel', style: TextStyle(color: context.appSubtext, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}
