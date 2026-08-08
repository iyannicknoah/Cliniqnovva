import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/rating_stars.dart';
import '../browse/providers/browse_provider.dart';
import 'models/review_model.dart';
import 'providers/reviews_provider.dart';

/// Pushed on top of the shell — reached from Settings, not a bottom-nav
/// tab. Part 24 Task 2: every review this patient has submitted, across
/// every clinic. Edit/Delete are only ENABLED within the 48h window as a
/// UI courtesy — the server re-checks this on every write regardless (see
/// [ReviewModel.isWithinEditWindow]'s own doc comment).
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReviewsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          'settings_reviews'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(child: Text('my_reviews_empty'.tr(), style: TextStyle(color: context.appSubtext)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _MyReviewCard(review: reviews[index]),
          );
        },
      ),
    );
  }
}

class _MyReviewCard extends ConsumerWidget {
  const _MyReviewCard({required this.review});

  final ReviewModel review;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('my_reviews_delete_confirm_title'.tr()),
        content: Text('my_reviews_delete_confirm_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('action_no_keep_it'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('action_delete'.tr(), style: const TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(reviewActionsProvider.notifier).remove(review.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('my_reviews_delete_success'.tr())));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchDetailProvider(review.branchId));
    final doctorAsync = ref.watch(doctorDetailProvider(review.doctorId));
    final canEdit = review.isWithinEditWindow && !review.isHidden;
    final isBusy = ref.watch(reviewActionsProvider).isLoading;

    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  branchAsync.valueOrNull?.branch.name ?? '…',
                  style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (review.createdAt != null)
                Text(DateFormat.yMMMd().format(review.createdAt!), style: TextStyle(color: context.appSubtext, fontSize: 11)),
            ],
          ),
          if (review.isHidden) ...[
            const SizedBox(height: 4),
            Text('my_reviews_hidden_note'.tr(), style: const TextStyle(color: AppColors.errorRed, fontSize: 11)),
          ],
          const SizedBox(height: 10),
          Text('review_rate_clinic_label'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 11)),
          RatingStars(rating: review.branchRating.toDouble(), showValue: false, size: 15),
          if (review.branchComment != null && review.branchComment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.branchComment!, style: TextStyle(color: context.appText, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Text(
            'review_rate_doctor_label'.tr(namedArgs: {'doctor': doctorAsync.valueOrNull?.name ?? '…'}),
            style: TextStyle(color: context.appSubtext, fontSize: 11),
          ),
          RatingStars(rating: review.doctorRating.toDouble(), showValue: false, size: 15),
          if (review.doctorComment != null && review.doctorComment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.doctorComment!, style: TextStyle(color: context.appText, fontSize: 13)),
          ],
          if (review.staffReply != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: context.appSecondaryBg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'browse_clinic_reply'.tr(),
                    style: TextStyle(color: context.appText, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(review.staffReply!.text, style: TextStyle(color: context.appSubtext, fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CliniqnovvaButton.text(
                  label: 'action_edit'.tr(),
                  isFullWidth: true,
                  onPressed: canEdit ? () => context.go('/my-reviews/${review.id}/edit') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CliniqnovvaButton.text(
                  label: 'action_delete'.tr(),
                  color: AppColors.errorRed,
                  isFullWidth: true,
                  isLoading: isBusy,
                  onPressed: canEdit ? () => _confirmDelete(context, ref) : null,
                ),
              ),
            ],
          ),
          if (!canEdit && !review.isHidden) ...[
            const SizedBox(height: 6),
            Text('my_reviews_edit_window_passed'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
