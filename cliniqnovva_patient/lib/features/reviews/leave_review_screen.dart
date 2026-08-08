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
import '../booking/providers/booking_provider.dart';
import '../browse/providers/browse_provider.dart';
import 'providers/reviews_provider.dart';

/// Pushed on top of the shell. Part 24 Task 1: two separate 1-5 star
/// ratings (branch + doctor), each with an optional comment. Submits to
/// the SAME POST /api/v1/reviews the spec already built (completed-
/// appointment/one-per-appointment/ownership all enforced server-side,
/// see reviews.service.js) — this screen only shapes the request and
/// surfaces whatever error comes back, never assumes success.
class LeaveReviewScreen extends ConsumerStatefulWidget {
  const LeaveReviewScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends ConsumerState<LeaveReviewScreen> {
  int _branchRating = 0;
  int _doctorRating = 0;
  final _branchCommentController = TextEditingController();
  final _doctorCommentController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _branchCommentController.dispose();
    _doctorCommentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      await ref.read(leaveReviewNotifierProvider.notifier).submit(
            appointmentId: widget.appointmentId,
            branchRating: _branchRating,
            branchComment: _branchCommentController.text.trim().isEmpty ? null : _branchCommentController.text.trim(),
            doctorRating: _doctorRating,
            doctorComment: _doctorCommentController.text.trim().isEmpty ? null : _doctorCommentController.text.trim(),
          );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(appointmentDetailProvider(widget.appointmentId));
    final submitted = ref.watch(leaveReviewNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/my-bookings'),
        ),
        title: Text(
          'review_leave_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: appointmentAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (appointment) {
          if (submitted != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcons.check, size: 56, color: context.appPrimary),
                    const SizedBox(height: 12),
                    Text(
                      'review_submitted_title'.tr(),
                      style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    CliniqnovvaButton(
                      label: 'action_done'.tr(),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/my-bookings'),
                    ),
                  ],
                ),
              ),
            );
          }

          final branchAsync = ref.watch(branchDetailProvider(appointment.branchId));
          final doctorAsync = ref.watch(doctorDetailProvider(appointment.doctorId));
          final branchName = branchAsync.valueOrNull?.branch.name ?? '…';
          final doctorName = doctorAsync.valueOrNull?.name ?? '…';
          final isLoading = ref.watch(leaveReviewNotifierProvider).isLoading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CliniqnovvaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'review_rate_clinic'.tr(namedArgs: {'clinic': branchName}),
                        style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      StarRatingInput(value: _branchRating, onChanged: (v) => setState(() => _branchRating = v)),
                      const SizedBox(height: 16),
                      CliniqnovvaTextField(
                        label: 'review_comment_optional'.tr(),
                        controller: _branchCommentController,
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
                      Text(
                        'review_rate_doctor'.tr(namedArgs: {'doctor': doctorName}),
                        style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      StarRatingInput(value: _doctorRating, onChanged: (v) => setState(() => _doctorRating = v)),
                      const SizedBox(height: 16),
                      CliniqnovvaTextField(
                        label: 'review_comment_optional'.tr(),
                        controller: _doctorCommentController,
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
                CliniqnovvaButton(
                  label: 'action_submit_review'.tr(),
                  isLoading: isLoading,
                  onPressed: (_branchRating > 0 && _doctorRating > 0) ? _submit : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
