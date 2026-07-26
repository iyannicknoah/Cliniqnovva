import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../patients/providers/patients_provider.dart';
import '../../reviews/models/review_model.dart';
import '../../reviews/providers/reviews_provider.dart';

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => AppIcon(
          AppIcons.star,
          size: 14,
          color: i < rating ? AppColors.skyBlue : context.appBorder,
        ),
      ),
    );
  }
}

/// Part 17 Task 2 — /doctor-reviews. Read-only — no reply/hide controls at
/// all, unlike the staff Reviews screen (Part 16). The server already
/// scopes this to reviews about the signed-in doctor specifically (see
/// reviews.controller.js's list(): a doctor-role caller's `doctorId` filter
/// is forced to their own uid, never client-supplied).
class DoctorReviewsScreen extends ConsumerWidget {
  const DoctorReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsListProvider(null));

    return Scaffold(
      backgroundColor: context.appBg,
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reviews About You',
              style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'What patients have said after visiting you. Read-only.',
              style: TextStyle(color: context.appSubtext, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: reviewsAsync.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
                data: (reviews) {
                  final visible = reviews.where((r) => !r.isHidden).toList();
                  if (visible.isEmpty) {
                    return Center(
                      child: Text(
                        'No reviews yet — they\'ll show up here once patients start leaving them.',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _DoctorReviewCard(review: visible[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorReviewCard extends ConsumerWidget {
  const _DoctorReviewCard({required this.review});

  final ReviewModel review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(review.patientId));

    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(firstName: patientAsync.valueOrNull?.name ?? '?', size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientAsync.valueOrNull?.name ?? 'Loading…',
                      style: TextStyle(color: context.appText, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: TextStyle(color: context.appSubtext, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.doctorRating),
            ],
          ),
          if (review.doctorComment != null && review.doctorComment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.doctorComment!, style: TextStyle(color: context.appText, fontSize: 13.5)),
          ],
          if (review.staffReply != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appSecondaryBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clinic reply',
                    style: TextStyle(color: context.appSubtext, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(review.staffReply!.text, style: TextStyle(color: context.appText, fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
