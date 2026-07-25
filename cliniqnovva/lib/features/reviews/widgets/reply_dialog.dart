import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../providers/reviews_provider.dart';

Future<void> showReplyDialog(BuildContext context, {required String reviewId, String? existingReply}) {
  return showDialog(
    context: context,
    builder: (context) => _ReplyDialog(reviewId: reviewId, existingReply: existingReply),
  );
}

class _ReplyDialog extends ConsumerStatefulWidget {
  const _ReplyDialog({required this.reviewId, this.existingReply});

  final String reviewId;
  final String? existingReply;

  @override
  ConsumerState<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends ConsumerState<_ReplyDialog> {
  late final _textController = TextEditingController(text: widget.existingReply ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Reply text is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await runWithFeedback(
        context,
        () => ref.read(reviewsNotifierProvider.notifier).reply(widget.reviewId, text),
        loadingMessage: 'Sending reply…',
        successMessage: 'Reply posted.',
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
      title: Text(widget.existingReply == null ? 'Reply to review' : 'Edit reply'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CliniqnovvaTextField(
              label: 'Reply',
              controller: _textController,
              hint: 'Thank the patient, or address their feedback…',
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
        SizedBox(
          width: 120,
          child: CliniqnovvaButton(label: 'Send', isLoading: _saving, onPressed: _saving ? null : _submit),
        ),
      ],
    );
  }
}
