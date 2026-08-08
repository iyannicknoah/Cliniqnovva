import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/rating_stars.dart';
import 'models/doctor_summary.dart';
import 'providers/browse_provider.dart';

const _dayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

/// Pushed on top of the shell (Part 19 Task 6). Part 20 Task 3: bio,
/// specialty, schedule overview, average rating, "Book with this doctor".
class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(doctorDetailProvider(doctorId));

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/browse'),
        ),
        title: Text(
          async.valueOrNull?.name ?? 'browse_doctor_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (doctor) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    AvatarWidget(firstName: doctor.name ?? '?', size: 72),
                    const SizedBox(height: 12),
                    Text(
                      doctor.name ?? '',
                      style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    if (doctor.specialty != null) ...[
                      const SizedBox(height: 2),
                      Text(doctor.specialty!, style: TextStyle(color: context.appSubtext, fontSize: 13)),
                    ],
                    const SizedBox(height: 8),
                    RatingStars(rating: doctor.averageRating, reviewCount: doctor.reviewCount),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (doctor.bio != null && doctor.bio!.isNotEmpty) ...[
                Text(
                  'browse_about_doctor'.tr(),
                  style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                CliniqnovvaCard(
                  child: Text(doctor.bio!, style: TextStyle(color: context.appText, fontSize: 13, height: 1.5)),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'browse_schedule_overview'.tr(),
                style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _ScheduleCard(doctor: doctor),
              const SizedBox(height: 28),
              CliniqnovvaButton(
                label: 'action_book_with_doctor'.tr(),
                onPressed: doctor.branchId == null
                    ? null
                    : () => context.go('/booking?branchId=${doctor.branchId}&doctorId=${doctor.id}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.doctor});

  final DoctorSummary doctor;

  @override
  Widget build(BuildContext context) {
    if (doctor.schedule.isEmpty) {
      return CliniqnovvaCard(
        child: Text('browse_no_schedule'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13)),
      );
    }

    final sorted = [...doctor.schedule]
      ..sort((a, b) => _dayOrder.indexOf(a.day).compareTo(_dayOrder.indexOf(b.day)));

    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sorted.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == sorted.length - 1 ? 0 : 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'day_${sorted[i].day}'.tr(),
                      style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${sorted[i].startTime} – ${sorted[i].endTime}',
                    style: TextStyle(color: context.appSubtext, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
