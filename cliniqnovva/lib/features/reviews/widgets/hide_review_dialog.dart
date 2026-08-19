import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../providers/reviews_provider.dart';

/// Part 16 Task 3 — hiding requires a reason (server-enforced too); the
/// caller is trusted to only offer this to Org Admin/Super Admin, and the
/// server re-checks the role regardless.
Future<void> showHideReviewDialog(BuildContext context, {required String reviewId}) {
  return showDialog(
    context: context,
    builder: (context) => _HideReviewDialog(reviewId: reviewId),
  );
}

class _HideReviewDialog extends ConsumerStatefulWidget {
  const _HideReviewDialog({required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<_HideReviewDialog> createState() => _HideReviewDialogState();
}

class _HideReviewDialogState extends ConsumerState<_HideReviewDialog> {
  final _reasonController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'A reason is required to hide a review.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await runWithFeedback(
        context,
        () => ref.read(reviewsNotifierProvider.notifier).setHidden(widget.reviewId, true, reason: reason),
        loadingMessage: 'Hiding review…',
        successMessage: 'Review hidden.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hide review?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes it from public averages immediately. The patient keeps their original review and can still see it themselves — this only hides it from staff/branch aggregates.',
            ),
            const SizedBox(height: 14),
            CliniqnovvaTextField(
              label: 'Reason',
              controller: _reasonController,
              hint: 'e.g. Inappropriate language, off-topic…',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        CliniqnovvaButton(label: 'Hide', isLoading: _saving, onPressed: _saving ? null : _submit),
      ],
    );
  }
}
