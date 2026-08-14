import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../models/service_summary.dart';

/// One tile in the Home screen's service grid — a fixed-shape card (name +
/// "N Clinics", bottom-aligned) matching the reference design exactly:
/// 100px tall, `context.appSecondaryBg`, 18-radius, 20px padding, plus a
/// large low-opacity [AppIcons.clinic] watermark peeking out the bottom-
/// right corner. [width] is computed by the caller ([ServicesGrid], via
/// `LayoutBuilder`) rather than here — a naive `MediaQuery.sizeOf(context)
/// .width * 0.45` looks right in isolation but doesn't account for the
/// page's own horizontal padding, so two cards + the grid's spacing no
/// longer fit the actually-available width and silently wrap to one per
/// row. [ServiceCard.viewAll] renders the grid's trailing "View all" tile
/// instead of a service name/count.
class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, required this.width, required this.onTap})
    : isViewAll = false;

  const ServiceCard.viewAll({super.key, required this.width, required this.onTap})
    : service = null,
      isViewAll = true;

  final ServiceSummary? service;
  final double width;
  final bool isViewAll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          width: width,
          height: 100,
          decoration: BoxDecoration(
            color: context.appSecondaryBg,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -14,
                child: Opacity(
                  opacity: 0.08,
                  child: AppIcon(AppIcons.clinic, size: 72, color: context.appText),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: isViewAll
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'action_view_all'.tr(),
                              style: TextStyle(color: context.appSubtext, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            AppIcon(AppIcons.arrowRight40, size: 20, color: context.appSubtext),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'home_service_clinic_count'.plural(service!.clinicCount),
                              style: TextStyle(color: context.appSubtext, fontSize: 15),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
