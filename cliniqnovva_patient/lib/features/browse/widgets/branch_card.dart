import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/rating_stars.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../models/branch_summary.dart';

/// One clinic/branch card — used on the Home screen's clinic lists (Task 1)
/// and the Browse screen's list (Task 2). Always full width — matches the
/// reference design exactly (its clinic card is `width: double.infinity`,
/// a fixed 227px banner image, not a narrow horizontally-scrolling tile).
/// Rating shown as a small overlay pill on the image, matching the "New"
/// badge (both top corners of the image). Below the name/subtitle, a
/// location row (pin icon in the brand's skyBlue + address text) shows
/// where the clinic is — separate from [_subtitle]'s distance/doctor-count
/// line, shown whenever a public/internal address exists.
class BranchCard extends StatelessWidget {
  const BranchCard({
    super.key,
    required this.branch,
    required this.onTap,
    this.isNew = false,
    this.distanceKm,
  });

  final BranchSummary branch;
  final VoidCallback onTap;
  final bool isNew;
  final double? distanceKm;

  /// "1.4km . 15 Doctors" — exact format/separator from the reference
  /// design (no space before "km", ". " between the two parts, capital
  /// "Doctors"/"Doctor" via the browse_doctor_count plural key). Falls
  /// back to the branch's public/internal address if neither distance nor
  /// a doctor count is available.
  String? get _subtitle {
    final parts = <String>[
      if (distanceKm != null) '${distanceKm!.toStringAsFixed(1)}km',
      if (branch.doctorCount > 0) 'browse_doctor_count'.plural(branch.doctorCount),
    ];
    if (parts.isNotEmpty) return parts.join(' . ');
    final address = branch.contactAddress;
    return address != null && address.isNotEmpty ? address : null;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: CliniqnovvaCard(
        padding: EdgeInsets.zero,
        showBorder: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 227,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
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
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.displayName ?? branch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (_subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      _subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.appSubtext, fontSize: 15),
                    ),
                  ],
                  if (branch.contactAddress != null && branch.contactAddress!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const AppIcon(AppIcons.mapPin, size: 16, color: AppColors.skyBlue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            branch.contactAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.appSubtext, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ShimmerBox(),
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
