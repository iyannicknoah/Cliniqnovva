import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../departments/widgets/branch_selector.dart';
import '../../patients/providers/patients_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../models/review_model.dart';
import '../providers/reviews_provider.dart';
import '../widgets/hide_review_dialog.dart';
import '../widgets/reply_dialog.dart';
import '../widgets/review_display.dart';

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inDays < 1) return 'today';
  if (diff.inDays == 1) return '1 day ago';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Part 16 Task 3 — /reviews. Branch/Clinic Admin: list, reply, hide
/// (hide itself narrower — Org Admin/Super Admin only, both client- and
/// server-gated). Redesigned 2026-07-25 to match the reference screenshot:
/// a rating-summary header (big average + count + star row, paired with the
/// 5-4-3-2-1 distribution bars), a Rating/Filter-by-patient row, then the
/// review cards.
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
          final isAllBranches = isOrgAdmin && ref.watch(showAllBranchesProvider);

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
                  child: effectiveBranchId == null && !isAllBranches
                      ? const NoBranchSelectedState()
                      : _ReviewsBody(
                          branchId: isAllBranches ? null : effectiveBranchId,
                          canHide: canHide,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewsBody extends ConsumerStatefulWidget {
  const _ReviewsBody({required this.branchId, required this.canHide});

  final String? branchId;
  final bool canHide;

  @override
  ConsumerState<_ReviewsBody> createState() => _ReviewsBodyState();
}

class _ReviewsBodyState extends ConsumerState<_ReviewsBody> {
  int? _ratingFilter;
  String? _patientFilter;

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(reviewsListProvider(widget.branchId));

    return reviewsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
      data: (reviews) {
        final isSample = reviews.isEmpty;

        final distribution = isSample
            ? sampleDistribution
            : {for (final stars in [5, 4, 3, 2, 1]) stars: reviews.where((r) => r.branchRating == stars).length};
        final averageRating = isSample
            ? sampleAverageRating
            : reviews.map((r) => r.branchRating).reduce((a, b) => a + b) / reviews.length;
        final ratingCount = isSample ? sampleRatingCount : reviews.length;

        var filtered = reviews;
        if (_ratingFilter != null) {
          filtered = filtered.where((r) => r.branchRating == _ratingFilter).toList();
        }
        if (_patientFilter != null) {
          filtered = filtered.where((r) => r.patientId == _patientFilter).toList();
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatingSummaryHeader(
                averageRating: averageRating,
                ratingCount: ratingCount,
                distribution: distribution,
              ),
              if (isSample) ...[
                const SizedBox(height: 8),
                Text(
                  'Sample preview — shown until this branch has real reviews.',
                  style: TextStyle(color: context.appSubtext, fontSize: 11.5, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  _RatingFilterDropdown(
                    value: _ratingFilter,
                    onChanged: (v) => setState(() => _ratingFilter = v),
                  ),
                  const SizedBox(width: 12),
                  _PatientFilterDropdown(
                    reviews: reviews,
                    value: _patientFilter,
                    onChanged: (v) => setState(() => _patientFilter = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isSample)
                Column(
                  children: [
                    for (final sample in sampleReviewCards) ...[
                      SimpleReviewCard(
                        comment: sample.comment,
                        rating: sample.rating,
                        name: sample.name,
                        timeLabel: '2 days ago',
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No reviews match this filter.', style: TextStyle(color: context.appSubtext)),
                )
              else
                Column(
                  children: [
                    for (final review in filtered) ...[
                      _ReviewCard(review: review, canHide: widget.canHide),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RatingFilterDropdown extends StatelessWidget {
  const _RatingFilterDropdown({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          hint: Text('Rating', style: TextStyle(color: context.appText)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: [
            DropdownMenuItem(value: null, child: Text('Rating', style: TextStyle(color: context.appText))),
            for (final stars in [5, 4, 3, 2, 1])
              DropdownMenuItem(value: stars, child: Text('$stars stars')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PatientFilterDropdown extends ConsumerWidget {
  const _PatientFilterDropdown({required this.reviews, required this.value, required this.onChanged});

  final List<ReviewModel> reviews;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientIds = reviews.map((r) => r.patientId).toSet().toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text('Filter by patient', style: TextStyle(color: context.appText)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          items: [
            DropdownMenuItem(value: null, child: Text('Filter by patient', style: TextStyle(color: context.appText))),
            for (final patientId in patientIds)
              DropdownMenuItem(
                value: patientId,
                child: _PatientOptionLabel(patientId: patientId),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PatientOptionLabel extends ConsumerWidget {
  const _PatientOptionLabel({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    return Text(patientAsync.valueOrNull?.name ?? '…');
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
    final patientName = patientAsync.valueOrNull?.name ?? 'Loading…';

    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.branchComment ?? review.doctorComment ?? 'No comment left.',
                  style: TextStyle(color: context.appText, fontSize: 14),
                ),
              ),
              if (review.isHidden) const StatusBadge(text: 'Hidden', type: BadgeType.error),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AvatarWidget(firstName: patientName, size: 26),
              const SizedBox(width: 8),
              ReviewStarRow(rating: review.branchRating),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$patientName · ${_formatDate(review.createdAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.appSubtext, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: _RatingBlock(
              label: doctorAsync.valueOrNull?.name ?? 'Doctor',
              rating: review.doctorRating,
              comment: review.doctorComment,
            ),
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
        ReviewStarRow(rating: rating),
        if (comment != null && comment!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comment!, style: TextStyle(color: context.appText, fontSize: 13)),
        ],
      ],
    );
  }
}
