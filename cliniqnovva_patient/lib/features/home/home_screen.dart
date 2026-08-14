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
import '../browse/models/service_summary.dart';
import '../browse/providers/browse_provider.dart';
import '../browse/widgets/branch_card.dart';
import '../browse/widgets/service_card.dart';
import '../chat/widgets/chat_bell.dart';
import '../notifications/widgets/notification_bell.dart';

/// Registers this device's push token once per app session (Part 25 Task
/// 4's prerequisite) — deliberately NOT `.autoDispose`, so it runs exactly
/// once for as long as the app process lives, regardless of how many times
/// Home rebuilds or the user navigates away and back.
final _fcmRegistrationProvider = FutureProvider<void>((ref) => NotificationService.registerDeviceToken());

/// Bottom-nav tab (Task 6 of Part 19; real content added Part 20 Task 1).
/// 2026-08-12/13 redesign: the greeting/upcoming-appointment/"Book an
/// Appointment" block is gone entirely — booking now only happens from a
/// clinic's own detail screen (tap a clinic -> Clinic Detail -> book with
/// a doctor there), so Home doesn't need a separate CTA or an appointment
/// status card. Layout is now: logo/wordmark top bar (+ notification/chat
/// buttons), a Services grid (first — explicit ask, so a patient can jump
/// straight to "who offers X" without scrolling past clinics), then a
/// single "Popular" clinic list capped at 6 — no separate "New" section
/// (explicit ask, 2026-08-13, to simplify back down to one list).
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
                const SizedBox(height: 20),
                async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: LoadingWidget(),
                  ),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ServicesGrid(services: data.services),
                      const SizedBox(height: 20),
                      ClinicList(
                        title: 'home_popular_clinics'.tr(),
                        branches: data.popular.take(6).toList(),
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

/// Logo + wordmark (left) and the notification/chat buttons (right) — same
/// mark as the Login/Register screens. Extracted so the dev sample-data
/// preview (`dev/home_preview_screen.dart`) can reuse it without depending
/// on [HomeScreen] itself.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CliniqnovvaLogo(size: 35, radius: 10),
        Text(
          AppConstants.appName,
          style: const TextStyle(color: AppColors.skyBlue, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        const NotificationBell(),
        const SizedBox(width: 10),
        const ChatBell(),
      ],
    );
  }
}

/// The top 3 services (by clinic count) plus a trailing "View all" tile —
/// a fixed 2x2 grid, matching the reference design exactly (it never shows
/// more than 4 cells). Shown ABOVE the clinic carousels per the explicit
/// ask, so a patient can jump straight to "which clinics offer X" without
/// scrolling past clinics first. Presentational (plain data in, no
/// provider watching) so the dev preview can feed it sample data directly.
class ServicesGrid extends StatelessWidget {
  const ServicesGrid({super.key, required this.services});

  final List<ServiceSummary> services;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    final sorted = [...services]..sort((a, b) => b.clinicCount.compareTo(a.clinicCount));
    final top = sorted.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Exactly 2 per row: half the ACTUALLY available width (not
        // MediaQuery's full device width, which ignores this page's own
        // horizontal padding and silently wraps to 1 per row — see
        // service_card.dart's doc comment).
        const spacing = 10.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final service in top)
              ServiceCard(
                service: service,
                width: cardWidth,
                onTap: () => context.go('/service-clinics?service=${Uri.encodeQueryComponent(service.name)}'),
              ),
            ServiceCard.viewAll(width: cardWidth, onTap: () => context.go('/explore-services')),
          ],
        );
      },
    );
  }
}

/// A vertical stack of full-width [BranchCard]s under a title + trailing
/// "View all" link — matches the reference exactly (its clinic card is
/// `width: double.infinity`, not a narrow horizontally-scrolling tile).
/// Same presentational split as [ServicesGrid], for the same reason (the
/// dev preview feeds it sample branches with no provider involved at all).
class ClinicList extends StatelessWidget {
  const ClinicList({
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600)),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.go('/browse'),
              child: Text(
                'action_view_all'.tr(),
                style: TextStyle(color: context.appSubtext, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final branch in branches) ...[
          Builder(
            builder: (context) {
              final lat = branch.latitude;
              final lng = branch.longitude;
              final distanceKm = (location != null && lat != null && lng != null)
                  ? Geolocator.distanceBetween(location!.latitude, location!.longitude, lat, lng) / 1000
                  : null;
              return BranchCard(
                branch: branch,
                isNew: isNew,
                distanceKm: distanceKm,
                onTap: () => context.go('/browse/${branch.id}'),
              );
            },
          ),
          if (branch != branches.last) const SizedBox(height: 20),
        ],
      ],
    );
  }
}
