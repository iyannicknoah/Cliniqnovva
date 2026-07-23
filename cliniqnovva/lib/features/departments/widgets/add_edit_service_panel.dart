import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../models/department_model.dart';
import '../models/service_model.dart';
import '../providers/departments_provider.dart';
import '../providers/services_provider.dart';

/// Part 7 Task 2 — "+ Add Service" is a right-edge SLIDE-OUT panel (spec's
/// explicit wording), distinct from the centered-modal quick-add pattern
/// used elsewhere (Add Branch, Add Clinic). Create when [service] is null,
/// edit otherwise.
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
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: _ServicePanel(branchId: branchId, service: service),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
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
        successMessage: _isEdit ? 'Service saved.' : 'Service added.',
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
    final departmentsAsync = ref.watch(departmentsProvider(widget.branchId));

    return Material(
      color: context.appCard,
      child: Container(
        width: 420,
        height: double.infinity,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: context.appBorder)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),
                ),
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
                organizationId: '',
                branchId: '',
                name: '(unknown department)',
              ),
          ];

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        'Select department',
        style: TextStyle(color: context.appSubtext, fontSize: 14),
      ),
      style: TextStyle(color: context.appText, fontSize: 15),
      dropdownColor: context.appCard,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: context.appCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          borderSide: BorderSide(color: context.appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          borderSide: BorderSide(color: context.appBorder),
        ),
      ),
      items: options
          .map(
            (d) => DropdownMenuItem(
              value: d.id,
              child: Text(
                d.isActive ? d.name : '${d.name} (inactive)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
