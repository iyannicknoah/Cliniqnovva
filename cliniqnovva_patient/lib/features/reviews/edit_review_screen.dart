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
import '../../shared/widgets/cliniqnovva_text_field.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/star_rating_input.dart';
import 'models/review_model.dart';
import 'providers/reviews_provider.dart';

/// Pushed on top of the shell. Part 24 Task 2's Edit action — same two-
/// rating-plus-comment shape as Leave Review, pre-filled, calling PATCH
/// instead of POST. The 48h-window/hidden checks are re-enforced
/// server-side regardless of whether My Reviews' Edit button was enabled.
class EditReviewScreen extends ConsumerStatefulWidget {
  const EditReviewScreen({super.key, required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<EditReviewScreen> createState() => _EditReviewScreenState();
}

class _EditReviewScreenState extends ConsumerState<EditReviewScreen> {
  int? _branchRating;
  int? _doctorRating;
  TextEditingController? _branchCommentController;
  TextEditingController? _doctorCommentController;
  String? _error;

  void _initFrom(ReviewModel review) {
    _branchRating ??= review.branchRating;
    _doctorRating ??= review.doctorRating;
    _branchCommentController ??= TextEditingController(text: review.branchComment ?? '');
    _doctorCommentController ??= TextEditingController(text: review.doctorComment ?? '');
  }

  @override
  void dispose() {
    _branchCommentController?.dispose();
    _doctorCommentController?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      await ref.read(reviewActionsProvider.notifier).edit(
            widget.reviewId,
            branchRating: _branchRating!,
            branchComment: _branchCommentController!.text.trim().isEmpty ? null : _branchCommentController!.text.trim(),
            doctorRating: _doctorRating!,
            doctorComment: _doctorCommentController!.text.trim().isEmpty ? null : _doctorCommentController!.text.trim(),
          );
      if (mounted) context.canPop() ? context.pop() : context.go('/my-reviews');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myReviewsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/my-reviews'),
        ),
        title: Text(
          'review_edit_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
        data: (reviews) {
          ReviewModel? review;
          for (final r in reviews) {
            if (r.id == widget.reviewId) {
              review = r;
              break;
            }
          }
          if (review == null) {
            return Center(child: Text('review_not_found'.tr(), style: TextStyle(color: context.appSubtext)));
          }
          _initFrom(review);
          final isLoading = ref.watch(reviewActionsProvider).isLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CliniqnovvaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('review_rate_clinic_label'.tr(), style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      StarRatingInput(value: _branchRating!, onChanged: (v) => setState(() => _branchRating = v)),
                      const SizedBox(height: 16),
                      CliniqnovvaTextField(
                        label: 'review_comment_optional'.tr(),
                        controller: _branchCommentController,
                        hint: 'Share your experience',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CliniqnovvaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('review_rate_doctor_generic_label'.tr(), style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      StarRatingInput(value: _doctorRating!, onChanged: (v) => setState(() => _doctorRating = v)),
                      const SizedBox(height: 16),
                      CliniqnovvaTextField(
                        label: 'review_comment_optional'.tr(),
                        controller: _doctorCommentController,
                        hint: 'Share your experience',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                CliniqnovvaButton(label: 'action_save'.tr(), isLoading: isLoading, onPressed: _save),
              ],
            ),
          );
        },
      ),
    );
  }
}
