import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../models/branch_summary.dart';

/// One clinic/branch card — used on the Home screen's Popular/New carousels
/// (Task 1) and the Browse screen's list (Task 2). [width] constrains it for
/// the horizontally-scrolling Home carousels; leave null for a full-width
/// list tile on Browse.
class BranchCard extends StatelessWidget {
  const BranchCard({
    super.key,
    required this.branch,
    required this.onTap,
    this.width,
    this.isNew = false,
    this.distanceKm,
  });

  final BranchSummary branch;
  final VoidCallback onTap;
  final double? width;
  final bool isNew;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final card = CliniqnovvaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  branch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              if (isNew) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.pillTealBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'browse_new_badge'.tr(),
                    style: const TextStyle(color: AppColors.pillTealText, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          RatingStars(rating: branch.averageRating, reviewCount: branch.reviewCount, size: 14),
          if (branch.address != null && branch.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                AppIcon(AppIcons.mapPin, size: 14, color: context.appSubtext),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    distanceKm != null
                        ? 'browse_address_with_distance'.tr(
                            namedArgs: {'address': branch.address!, 'distance': distanceKm!.toStringAsFixed(1)},
                          )
                        : branch.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appSubtext, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (branch.servicesOffered.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: branch.servicesOffered
                  .take(3)
                  .map(
                    (service) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: context.appSecondaryBg, borderRadius: BorderRadius.circular(20)),
                      child: Text(service, style: TextStyle(color: context.appText, fontSize: 11)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    final tappable = InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: card);
    return width != null ? SizedBox(width: width, child: tappable) : tappable;
  }
}
