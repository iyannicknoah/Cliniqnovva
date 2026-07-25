import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../departments/widgets/branch_selector.dart';
import '../../patients/providers/patients_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../models/review_model.dart';
import '../providers/reviews_provider.dart';
import '../widgets/hide_review_dialog.dart';
import '../widgets/reply_dialog.dart';

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
          color: i < rating ? AppColors.pillAmberText : context.appBorder,
        ),
      ),
    );
  }
}

/// Part 16 Task 3 — /reviews. Branch/Clinic Admin: list, reply, hide
/// (hide itself narrower — Org Admin/Super Admin only, both client- and
/// server-gated).
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          final role = data?['role'] as String?;
          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final canHide = role == AppConstants.roleClinicAdmin || role == AppConstants.roleSuperAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final effectiveBranchId = isOrgAdmin ? ref.watch(activeBranchIdProvider) : ownBranchId;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Reviews',
                        style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isOrgAdmin) const BranchSelector(),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: effectiveBranchId == null
                      ? const NoBranchSelectedState()
                      : _ReviewList(branchId: effectiveBranchId, canHide: canHide),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewList extends ConsumerWidget {
  const _ReviewList({required this.branchId, required this.canHide});

  final String branchId;
  final bool canHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsListProvider(branchId));

    return reviewsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
      data: (reviews) => reviews.isEmpty
          ? Center(child: Text('No reviews yet.', style: TextStyle(color: context.appSubtext)))
          : ListView.separated(
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _ReviewCard(review: reviews[i], canHide: canHide),
            ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.review, required this.canHide});

  final ReviewModel review;
  final bool canHide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(review.patientId));
    final doctorAsync = ref.watch(staffDetailProvider(review.doctorId));

    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(firstName: patientAsync.valueOrNull?.name ?? '?', size: 30),
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
              if (review.isHidden)
                const StatusBadge(text: 'Hidden', type: BadgeType.error),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RatingBlock(
                  label: 'Branch',
                  rating: review.branchRating,
                  comment: review.branchComment,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _RatingBlock(
                  label: doctorAsync.valueOrNull?.name ?? 'Doctor',
                  rating: review.doctorRating,
                  comment: review.doctorComment,
                ),
              ),
            ],
          ),
          if (review.staffReply != null) ...[
            const SizedBox(height: 14),
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
                  Text(review.staffReply!.text, style: TextStyle(color: context.appText, fontSize: 13.5)),
                ],
              ),
            ),
          ],
          if (review.isHidden && review.hiddenReason != null) ...[
            const SizedBox(height: 10),
            Text(
              'Hidden reason: ${review.hiddenReason}',
              style: TextStyle(color: context.appSubtext, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              CliniqnovvaButton.text(
                label: review.staffReply == null ? 'Reply' : 'Edit reply',
                color: context.appText,
                onPressed: () => showReplyDialog(
                  context,
                  reviewId: review.id,
                  existingReply: review.staffReply?.text,
                ),
              ),
              if (canHide)
                CliniqnovvaButton.text(
                  label: review.isHidden ? 'Unhide' : 'Hide',
                  color: context.appSubtext,
                  onPressed: () => review.isHidden
                      ? ref.read(reviewsNotifierProvider.notifier).setHidden(review.id, false)
                      : showHideReviewDialog(context, reviewId: review.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingBlock extends StatelessWidget {
  const _RatingBlock({required this.label, required this.rating, this.comment});

  final String label;
  final int rating;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.appSubtext, fontSize: 12)),
        const SizedBox(height: 4),
        _StarRow(rating: rating),
        if (comment != null && comment!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comment!, style: TextStyle(color: context.appText, fontSize: 13)),
        ],
      ],
    );
  }
}
