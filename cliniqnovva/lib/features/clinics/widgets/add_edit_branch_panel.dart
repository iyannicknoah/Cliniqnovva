import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../staff/widgets/add_edit_staff_panel.dart';
import '../models/branch_model.dart';
import '../providers/branches_provider.dart';
import 'branch_form.dart';

/// Part 6 Task 4 — Add/Edit Branch as a centered 480px modal (the standard
/// quick-form pattern). Create when [branch] is null, edit otherwise.
/// [hoursOnly] is the Branch Admin mode: working hours are the only
/// editable fields.
Future<void> showBranchPanel(
  BuildContext context, {
  BranchModel? branch,
  bool hoursOnly = false,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Branch',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: _BranchPanel(branch: branch, hoursOnly: hoursOnly),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _BranchPanel extends ConsumerStatefulWidget {
  const _BranchPanel({this.branch, required this.hoursOnly});

  final BranchModel? branch;
  final bool hoursOnly;

  @override
  ConsumerState<_BranchPanel> createState() => _BranchPanelState();
}

class _BranchPanelState extends ConsumerState<_BranchPanel> {
  final _formKey = GlobalKey<BranchFormState>();
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.branch != null;

  String get _title => widget.hoursOnly
      ? 'Edit working hours'
      : _isEdit
      ? 'Edit Branch'
      : 'Add Branch';

  Future<void> _save() async {
    final form = _formKey.currentState!;
    final validationError = form.validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(branchesNotifierProvider.notifier);
      if (_isEdit) {
        await runWithFeedback(
          context,
          () => notifier.updateBranch(widget.branch!.id, form.buildBody()),
          loadingMessage: 'Saving branch…',
          successMessage: 'Branch saved.',
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        final created = await runWithFeedback(
          context,
          () => notifier.createBranch(form.buildBody()),
          loadingMessage: 'Creating branch…',
          successMessage: 'Branch created.',
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        // Step 2 (2026-07-25) — immediately prompt for this branch's admin,
        // so a newly created branch is never left without one. Dismissible
        // like any other panel — the branch itself is already saved either
        // way, this just offers to do the admin right now instead of later
        // from the Staff screen.
        showStaffPanel(
          context,
          branchId: created.id,
          lockedRole: AppConstants.roleBranchAdmin,
        );
      }
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
    return Material(
      color: context.appCard,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: context.appBorder),
        ),
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                BranchForm(
                  key: _formKey,
                  initial: widget.branch,
                  hoursOnly: widget.hoursOnly,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pillRedBg,
                      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.pillRedText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                CliniqnovvaButton(
                  label: 'Save',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
