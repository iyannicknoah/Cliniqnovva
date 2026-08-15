import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/success_dialog.dart';
import '../models/department_model.dart';
import '../providers/departments_provider.dart';

/// Part 7 Task 1 — a department is name-only, so a small centered dialog is
/// enough (no need for the full quick-add modal chrome used by Add
/// Branch/Add Clinic). Create when [department] is null (needs [branchId]),
/// rename otherwise.
Future<void> showDepartmentDialog(
  BuildContext context, {
  String? branchId,
  DepartmentModel? department,
}) {
  assert(
    department != null || branchId != null,
    'branchId is required when creating a new department',
  );
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _DepartmentDialog(branchId: branchId, department: department),
  );
}

class _DepartmentDialog extends ConsumerStatefulWidget {
  const _DepartmentDialog({this.branchId, this.department});

  final String? branchId;
  final DepartmentModel? department;

  @override
  ConsumerState<_DepartmentDialog> createState() => _DepartmentDialogState();
}

class _DepartmentDialogState extends ConsumerState<_DepartmentDialog> {
  final _nameController = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.department != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.department?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Department name is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(departmentsNotifierProvider.notifier);
      await runWithFeedback(
        context,
        () => _isEdit
            ? notifier.rename(widget.department!.id, name)
            : notifier.create(branchId: widget.branchId!, name: name),
        loadingMessage: _isEdit ? 'Saving department…' : 'Adding department…',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessDialog(
        context,
        message: _isEdit ? 'Department saved.' : 'Department added.',
      );
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
      title: Text(_isEdit ? 'Rename Department' : 'Add Department'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CliniqnovvaTextField(
              label: 'Department name',
              controller: _nameController,
              hint: 'e.g. General Medicine',
              errorText: _error,
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 90,
          child: CliniqnovvaButton(
            label: _isEdit ? 'Save' : 'Add',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }
}
