import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../browse/models/branch_summary.dart';
import '../browse/providers/browse_provider.dart';
import '../browse/widgets/branch_card.dart';

/// Streams the signed-in patient's own /users/{uid} doc (Firestore rules
/// already allow `request.auth.uid == userId` reads — no backend call
/// needed just to show a name).
final _profileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = FirebaseService.currentUserId;
  if (uid == null) return Stream.value(null);
  return FirebaseService.userDoc(uid).snapshots().map((doc) => doc.data());
});

/// Bottom-nav tab (Task 6 of Part 19; real content added Part 20 Task 1):
/// greeting, upcoming-appointment card (once Part 21 has bookings to show),
/// Popular Clinics / New on Cliniqnovva carousels, and a Book an Appointment CTA.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(_profileProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: profile.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          final name = (data?['name'] as String?)?.split(' ').first ?? '';
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(homeBrowseProvider);
                ref.invalidate(upcomingAppointmentProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'home_greeting'.tr(namedArgs: {'name': name}),
                      style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    Text('home_subtitle'.tr(), style: TextStyle(color: context.appSubtext)),
                    const _UpcomingAppointmentSection(),
                    const SizedBox(height: 24),
                    CliniqnovvaButton(
                      label: 'home_book_appointment'.tr(),
                      onPressed: () => context.go('/browse'),
                    ),
                    const SizedBox(height: 28),
                    _BranchCarouselSection(
                      title: 'home_popular_clinics'.tr(),
                      provider: homeBrowseProvider,
                      selector: (data) => data.popular,
                    ),
                    const SizedBox(height: 24),
                    _BranchCarouselSection(
                      title: 'home_new_clinics'.tr(),
                      provider: homeBrowseProvider,
                      selector: (data) => data.newOnes,
                      isNew: true,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UpcomingAppointmentSection extends ConsumerWidget {
  const _UpcomingAppointmentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointment = ref.watch(upcomingAppointmentProvider).valueOrNull;
    if (appointment == null) return const SizedBox(height: 20);

    // Data source lands in Part 21 (booking) — this card is ready to render
    // whatever shape that endpoint returns once upcomingAppointmentProvider
    // is wired to it.
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: CliniqnovvaCard(
        title: 'home_upcoming_appointment'.tr(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${appointment['branchName'] ?? ''}', style: TextStyle(color: context.appText)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CliniqnovvaButton.text(
                    label: 'action_reschedule'.tr(),
                    onPressed: () => context.go('/my-bookings/${appointment['id']}'),
                  ),
                ),
                Expanded(
                  child: CliniqnovvaButton.text(
                    label: 'action_cancel_appointment'.tr(),
                    color: AppColors.errorRed,
                    onPressed: () => context.go('/my-bookings/${appointment['id']}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchCarouselSection extends ConsumerWidget {
  const _BranchCarouselSection({
    required this.title,
    required this.provider,
    required this.selector,
    this.isNew = false,
  });

  final String title;
  final ProviderListenable<AsyncValue<HomeBrowseData>> provider;
  final List<BranchSummary> Function(HomeBrowseData) selector;
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final location = ref.watch(userLocationProvider).valueOrNull;

    return async.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const SizedBox(height: 140, child: LoadingWidget()),
        ],
      ),
      error: (e, st) => const SizedBox.shrink(),
      data: (data) {
        final branches = selector(data);
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
                      ? Geolocator.distanceBetween(location.latitude, location.longitude, lat, lng) / 1000
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
      },
    );
  }
}
