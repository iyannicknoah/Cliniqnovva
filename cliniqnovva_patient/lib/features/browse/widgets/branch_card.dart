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
/// list tile on Browse. Redesigned 2026-08-12: a banner image up top (with
/// the rating as a small overlay pill, matching the "New" badge) with the
/// name and a "distance • N doctors" subtitle below it, replacing the old
/// image-less title-row layout.
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

  String? get _subtitle {
    final parts = <String>[
      if (distanceKm != null) '${distanceKm!.toStringAsFixed(1)} km',
      if (branch.doctorCount > 0) 'browse_doctor_count'.plural(branch.doctorCount),
    ];
    if (parts.isNotEmpty) return parts.join(' • ');
    final address = branch.contactAddress;
    return address != null && address.isNotEmpty ? address : null;
  }

  @override
  Widget build(BuildContext context) {
    final card = CliniqnovvaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BranchImage(url: branch.imageUrl),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: RatingBadge(rating: branch.averageRating, reviewCount: branch.reviewCount),
                  ),
                  if (isNew)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pillTealBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'browse_new_badge'.tr(),
                          style: const TextStyle(
                            color: AppColors.pillTealText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.displayName ?? branch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (_subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appSubtext, fontSize: 12.5),
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
                            decoration: BoxDecoration(
                              color: context.appSecondaryBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(service, style: TextStyle(color: context.appText, fontSize: 11)),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final tappable = InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: card);
    return width != null ? SizedBox(width: width, child: tappable) : tappable;
  }
}

/// The banner image, or a themed placeholder for the (currently common)
/// case of a branch with no public profile image set up yet — never a
/// broken-image icon or blank gap.
class _BranchImage extends StatelessWidget {
  const _BranchImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) return _Placeholder(context: context);
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null ? child : _Placeholder(context: context),
      errorBuilder: (context, error, stackTrace) => _Placeholder(context: context),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Container(
      color: context.appSecondaryBg,
      alignment: Alignment.center,
      child: AppIcon(AppIcons.clinic, size: 32, color: context.appSubtext),
    );
  }
}
