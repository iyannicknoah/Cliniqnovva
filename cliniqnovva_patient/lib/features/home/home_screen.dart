import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/cliniqnovva_logo.dart';
import '../../shared/widgets/loading_widget.dart';
import '../browse/models/branch_summary.dart';
import '../browse/providers/browse_provider.dart';
import '../browse/widgets/branch_card.dart';
import '../notifications/widgets/notification_bell.dart';

/// Registers this device's push token once per app session (Part 25 Task
/// 4's prerequisite) — deliberately NOT `.autoDispose`, so it runs exactly
/// once for as long as the app process lives, regardless of how many times
/// Home rebuilds or the user navigates away and back.
final _fcmRegistrationProvider = FutureProvider<void>((ref) => NotificationService.registerDeviceToken());

/// Bottom-nav tab (Task 6 of Part 19; real content added Part 20 Task 1).
/// 2026-08-12 redesign: the greeting/upcoming-appointment/"Book an
/// Appointment" block is gone entirely — booking now only happens from a
/// clinic's own detail screen (tap a clinic -> Clinic Detail -> book with
/// a doctor there), so Home doesn't need a separate CTA or an appointment
/// status card. Layout is now: logo/wordmark top bar, Services (first —
/// explicit ask, so a patient can jump straight to "who offers X" without
/// scrolling past clinics), then the Popular/New clinic carousels.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_fcmRegistrationProvider);
    final async = ref.watch(homeBrowseProvider);
    final location = ref.watch(userLocationProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeBrowseProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeTopBar(),
                const SizedBox(height: 28),
                async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: LoadingWidget(),
                  ),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ServicesRow(services: data.services),
                      const SizedBox(height: 24),
                      ClinicCarousel(
                        title: 'home_popular_clinics'.tr(),
                        branches: data.popular,
                        location: location,
                      ),
                      const SizedBox(height: 24),
                      ClinicCarousel(
                        title: 'home_new_clinics'.tr(),
                        branches: data.newOnes,
                        isNew: true,
                        location: location,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo + wordmark (left) and the notification bell (right) — same mark as
/// the Login/Register screens. Extracted so the dev sample-data preview
/// (`dev/home_preview_screen.dart`) can reuse it without depending on
/// [HomeScreen] itself.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CliniqnovvaLogo(size: 32, radius: 10),
        const SizedBox(width: 8),
        Text(
          AppConstants.appName,
          style: const TextStyle(color: AppColors.skyBlue, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        const NotificationBell(),
      ],
    );
  }
}

/// Deduped service/department tags across every public branch (already
/// deduped + sorted server-side, see [HomeBrowseData.services]) — shown
/// ABOVE the clinic carousels per the explicit ask, so a patient can jump
/// straight to "which clinics offer X" without scrolling past clinics
/// first. Tapping a service opens Browse pre-filtered to it. Presentational
/// (plain data in, no provider watching) so the dev preview can feed it
/// sample data directly instead of overriding a provider.
class ServicesRow extends StatelessWidget {
  const ServicesRow({super.key, required this.services});

  final List<String> services;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'home_services'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final service = services[index];
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.go('/browse?department=${Uri.encodeQueryComponent(service)}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: context.appSecondaryBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    service,
                    style: TextStyle(color: context.appText, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A horizontally-scrolling row of [BranchCard]s under a title — same
/// presentational split as [ServicesRow], for the same reason (the dev
/// preview feeds it sample branches with no provider involved at all).
class ClinicCarousel extends StatelessWidget {
  const ClinicCarousel({
    super.key,
    required this.title,
    required this.branches,
    this.isNew = false,
    this.location,
  });

  final String title;
  final List<BranchSummary> branches;
  final bool isNew;
  final Position? location;

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: branches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final branch = branches[index];
              final lat = branch.latitude;
              final lng = branch.longitude;
              final distanceKm = (location != null && lat != null && lng != null)
                  ? Geolocator.distanceBetween(location!.latitude, location!.longitude, lat, lng) / 1000
                  : null;
              return BranchCard(
                branch: branch,
                width: 260,
                isNew: isNew,
                distanceKm: distanceKm,
                onTap: () => context.go('/browse/${branch.id}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
