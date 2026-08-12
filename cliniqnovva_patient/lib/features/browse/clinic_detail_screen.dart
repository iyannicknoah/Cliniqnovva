import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/rating_stars.dart';
import '../chat/providers/chats_provider.dart';
import '../reviews/providers/reviews_provider.dart';
import 'models/branch_review_summary.dart';
import 'models/branch_summary.dart';
import 'models/doctor_summary.dart';
import 'providers/browse_provider.dart';

/// Pushed on top of the shell (Part 19 Task 6). Part 20 Task 3: branch info,
/// its doctor list, and a paginated read-only reviews list.
class ClinicDetailScreen extends ConsumerWidget {
  const ClinicDetailScreen({super.key, required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchDetailProvider(branchId));

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
          async.valueOrNull?.branch.displayName ?? 'browse_clinic_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BranchInfoCard(branch: data.branch),
              const SizedBox(height: 12),
              _MessageClinicButton(branchId: branchId, clinicId: data.branch.clinicId),
              const SizedBox(height: 24),
              Text(
                'browse_doctors_title'.tr(),
                style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (data.doctors.isEmpty)
                Text('browse_no_doctors'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13))
              else
                ...data.doctors.map(
                  (doctor) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DoctorTile(doctor: doctor, branchId: branchId),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'browse_reviews_title'.tr(),
                style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _ReviewsList(branchId: branchId),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchInfoCard extends StatelessWidget {
  const _BranchInfoCard({required this.branch});

  final BranchSummary branch;

  @override
  Widget build(BuildContext context) {
    final address = branch.contactAddress;
    final phone = branch.contactPhone;

    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (branch.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  branch.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          RatingStars(rating: branch.averageRating, reviewCount: branch.reviewCount),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                AppIcon(AppIcons.mapPin, size: 15, color: context.appSubtext),
                const SizedBox(width: 6),
                Expanded(child: Text(address, style: TextStyle(color: context.appText, fontSize: 13))),
              ],
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                AppIcon(AppIcons.phone, size: 15, color: context.appSubtext),
                const SizedBox(width: 6),
                Text(phone, style: TextStyle(color: context.appText, fontSize: 13)),
              ],
            ),
          ],
          if (branch.workingHours != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                AppIcon(AppIcons.clock, size: 15, color: context.appSubtext),
                const SizedBox(width: 6),
                Text(
                  branch.is24Hours
                      ? 'browse_open_24_hours'.tr()
                      : 'browse_working_hours'.tr(
                          namedArgs: {
                            'start': branch.workingHoursStart ?? '',
                            'end': branch.workingHoursEnd ?? '',
                          },
                        ),
                  style: TextStyle(color: context.appText, fontSize: 13),
                ),
              ],
            ),
          ],
          if (branch.umugandaSaturdayHours != null) ...[
            const SizedBox(height: 8),
            Text('browse_umuganda_note'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Part 25 Task 1's actual "start a new thread" entry point — "Message a
/// Clinic" on the Chat List screen just opens Browse; the real call
/// happens once a specific branch is chosen, here. No appointment or
/// prior relationship required (Task 1's explicit DONE CONDITION).
class _MessageClinicButton extends ConsumerStatefulWidget {
  const _MessageClinicButton({required this.branchId, required this.clinicId});

  final String branchId;
  final String clinicId;

  @override
  ConsumerState<_MessageClinicButton> createState() => _MessageClinicButtonState();
}

class _MessageClinicButtonState extends ConsumerState<_MessageClinicButton> {
  bool _loading = false;

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      final chatId = await ref
          .read(chatsNotifierProvider.notifier)
          .startChat(clinicId: widget.clinicId, branchId: widget.branchId);
      if (mounted) context.go('/chat/$chatId');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaButton.text(
      label: 'chat_message_this_clinic'.tr(),
      isFullWidth: true,
      isLoading: _loading,
      onPressed: _loading ? null : _start,
    );
  }
}

class _DoctorTile extends StatelessWidget {
  const _DoctorTile({required this.doctor, required this.branchId});

  final DoctorSummary doctor;
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/browse/$branchId/doctors/${doctor.id}'),
      child: CliniqnovvaCard(
        child: Row(
          children: [
            AvatarWidget(firstName: doctor.name ?? '?', size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name ?? '',
                    style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (doctor.specialty != null)
                    Text(doctor.specialty!, style: TextStyle(color: context.appSubtext, fontSize: 12)),
                  const SizedBox(height: 4),
                  RatingStars(rating: doctor.averageRating, reviewCount: doctor.reviewCount, size: 13),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CliniqnovvaButton(
              label: 'action_book'.tr(),
              isFullWidth: false,
              onPressed: () => context.go('/booking?branchId=$branchId&doctorId=${doctor.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsList extends ConsumerWidget {
  const _ReviewsList({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchReviewsProvider(branchId));

    return async.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: LoadingWidget()),
      error: (e, st) => Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext)),
      data: (state) {
        if (state.reviews.isEmpty) {
          return Text('browse_no_reviews'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13));
        }
        return Column(
          children: [
            ...state.reviews.map(
              (review) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReviewTile(review: review)),
            ),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CliniqnovvaButton.text(
                  label: state.isLoadingMore ? 'browse_loading_more'.tr() : 'browse_load_more_reviews'.tr(),
                  isLoading: state.isLoadingMore,
                  onPressed: () => ref.read(branchReviewsProvider(branchId).notifier).loadMore(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends ConsumerStatefulWidget {
  const _ReviewTile({required this.review});

  final BranchReviewSummary review;

  @override
  ConsumerState<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends ConsumerState<_ReviewTile> {
  bool _reporting = false;

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('review_report_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('review_report_body'.tr()),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(hintText: 'review_report_reason_hint'.tr()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('action_cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('review_report_submit'.tr(), style: const TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reporting = true);
    try {
      await ref.read(reviewActionsProvider.notifier).flag(widget.review.id, reason: reasonController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('review_report_success'.tr())));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingStars(rating: review.branchRating.toDouble(), showValue: false, size: 14),
              const Spacer(),
              Text(
                DateFormat.yMMMd().format(review.createdAt),
                style: TextStyle(color: context.appSubtext, fontSize: 11),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _reporting ? null : _report,
                child: _reporting
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: context.appSubtext))
                    : AppIcon(AppIcons.flag, size: 14, color: context.appSubtext),
              ),
            ],
          ),
          if (review.branchComment != null && review.branchComment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.branchComment!, style: TextStyle(color: context.appText, fontSize: 13)),
          ],
          if (review.staffReply != null) ...[
            const SizedBox(height: 10),
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
        ],
      ),
    );
  }
}
