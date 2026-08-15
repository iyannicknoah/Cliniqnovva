import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/success_dialog.dart';
import '../models/department_model.dart';
import '../models/service_model.dart';
import '../providers/departments_provider.dart';
import '../providers/services_provider.dart';

/// Part 7 Task 2 originally made "+ Add Service" a right-edge SLIDE-OUT
/// panel. 2026-08-14, explicit user instruction — switched to the same
/// centered, rounded-corner modal pattern used elsewhere (Add Branch, Add
/// Clinic) for consistency. Create when [service] is null, edit otherwise.
Future<void> showServicePanel(
  BuildContext context, {
  required String branchId,
  ServiceModel? service,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Service',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: _ServicePanel(branchId: branchId, service: service),
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

class _ServicePanel extends ConsumerStatefulWidget {
  const _ServicePanel({required this.branchId, this.service});

  final String branchId;
  final ServiceModel? service;

  @override
  ConsumerState<_ServicePanel> createState() => _ServicePanelState();
}

class _ServicePanelState extends ConsumerState<_ServicePanel> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  String? _departmentId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    if (service != null) {
      _nameController.text = service.name;
      _durationController.text = service.defaultDurationMins.toString();
      _priceController.text = service.defaultPriceRwf.toString();
      _departmentId = service.departmentId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    final price = int.tryParse(_priceController.text.trim());

    if (name.isEmpty) {
      setState(() => _error = 'Service name is required.');
      return;
    }
    if (_departmentId == null) {
      setState(() => _error = 'Select a department.');
      return;
    }
    if (duration == null || duration <= 0) {
      setState(() => _error = 'Default duration must be a positive number of minutes.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Default price must be a positive whole number (RWF).');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(servicesNotifierProvider.notifier);
      await runWithFeedback(
        context,
        () => _isEdit
            ? notifier.updateService(
                widget.service!.id,
                name: name,
                departmentId: _departmentId,
                defaultDurationMins: duration,
                defaultPriceRwf: price,
              )
            : notifier.create(
                branchId: widget.branchId,
                departmentId: _departmentId!,
                name: name,
                defaultDurationMins: duration,
                defaultPriceRwf: price,
              ),
        loadingMessage: _isEdit ? 'Saving service…' : 'Adding service…',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessDialog(
        context,
        message: _isEdit ? 'Service saved.' : 'Service added.',
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
    final departmentsAsync = ref.watch(departmentsProvider(widget.branchId));

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
                        _isEdit ? 'Edit Service' : 'Add Service',
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
                CliniqnovvaTextField(
                  label: 'Service name',
                  controller: _nameController,
                  hint: 'e.g. General Consultation',
                ),
                const SizedBox(height: 16),
                Text(
                  'Department',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                departmentsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    '$e',
                    style: const TextStyle(color: AppColors.errorRed),
                  ),
                  data: (departments) => _DepartmentDropdown(
                    departments: departments,
                    value: _departmentId,
                    onChanged: (id) => setState(() => _departmentId = id),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CliniqnovvaTextField(
                        label: 'Default duration (mins)',
                        controller: _durationController,
                        hint: 'e.g. 30',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CliniqnovvaTextField(
                        label: 'Default price (RWF)',
                        controller: _priceController,
                        hint: 'e.g. 5000',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pillRedBg,
                      borderRadius: BorderRadius.circular(
                        AppTheme.inputRadius,
                      ),
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
                const SizedBox(height: 16),
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

class _DepartmentDropdown extends StatelessWidget {
  const _DepartmentDropdown({
    required this.departments,
    required this.value,
    required this.onChanged,
  });

  final List<DepartmentModel> departments;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // A department the caller passed in (e.g. editing a service whose
    // department was since deactivated) must still render even if it isn't
    // in the active list, or DropdownButton throws on an unmatched value.
    final options = departments.any((d) => d.id == value)
        ? departments
        : [
            ...departments,
            if (value != null)
              DepartmentModel(
                id: value!,
                clinicId: '',
                branchId: '',
                name: '(unknown department)',
              ),
          ];

    return AppSelect(
      value: value,
      hint: 'Select department',
      options: options
          .map(
            (d) => AppSelectOption(
              value: d.id,
              label: d.isActive ? d.name : '${d.name} (inactive)',
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
