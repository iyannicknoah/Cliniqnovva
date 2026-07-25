import 'dart:math';

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
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../departments/models/department_model.dart';
import '../../departments/providers/departments_provider.dart';
import '../models/staff_model.dart';
import '../providers/staff_provider.dart';

String _generatePassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  final rand = Random.secure();
  return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// Part 8 Task 1 — "+ Add Staff" panel. Create when [staff] is null (needs
/// [branchId] — password field shown, admin types one or generates one);
/// edit otherwise (name/phone/email/specialty/department only — changing an
/// existing account's password is a separate "change password" flow, not
/// part of this form).
Future<void> showStaffPanel(
  BuildContext context, {
  String? branchId,
  StaffModel? staff,
}) {
  assert(
    staff != null || branchId != null,
    'branchId is required when creating a new staff member',
  );
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Staff',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        Center(child: _StaffPanel(branchId: branchId, staff: staff)),
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

class _StaffPanel extends ConsumerStatefulWidget {
  const _StaffPanel({this.branchId, this.staff});

  final String? branchId;
  final StaffModel? staff;

  @override
  ConsumerState<_StaffPanel> createState() => _StaffPanelState();
}

class _StaffPanelState extends ConsumerState<_StaffPanel> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = AppConstants.roleDoctor;
  String? _departmentId;
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.staff != null;
  bool get _isDoctor => _role == AppConstants.roleDoctor;

  @override
  void initState() {
    super.initState();
    final staff = widget.staff;
    if (staff != null) {
      _nameController.text = staff.name;
      _phoneController.text = staff.phone ?? '';
      _emailController.text = staff.email ?? '';
      _specialtyController.text = staff.specialty ?? '';
      _role = staff.role;
      _departmentId = staff.departmentIds.isNotEmpty
          ? staff.departmentIds.first
          : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specialtyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Email is required.');
      return;
    }
    if (!_isEdit && password.isEmpty) {
      setState(() => _error = 'Set a password, or click Generate.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(staffNotifierProvider.notifier);
      if (_isEdit) {
        await runWithFeedback(
          context,
          () => notifier.updateStaff(
            widget.staff!.id,
            name: name,
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            email: email,
            specialty: _isDoctor ? _specialtyController.text.trim() : null,
            departmentIds: _isDoctor && _departmentId != null
                ? [_departmentId!]
                : null,
          ),
          loadingMessage: 'Saving staff member…',
          successMessage: 'Staff member saved.',
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        final created = await notifier.create(
          email: email,
          password: password,
          displayName: name,
          role: _role,
          branchId: widget.branchId!,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          specialty: _isDoctor ? _specialtyController.text.trim() : null,
          departmentIds: _isDoctor && _departmentId != null
              ? [_departmentId!]
              : null,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        await _showCredentialsDialog(created.email ?? email, password);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _showCredentialsDialog(String email, String password) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Staff account created'),
        content: SelectableText(
          'Login: $email\nTemp password: $password\n\nShare this with them directly — no email was sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                        _isEdit ? 'Edit Staff' : 'Add Staff',
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
                CliniqnovvaTextField(label: 'Name', controller: _nameController),
                const SizedBox(height: 16),
                Text(
                  'Role',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  isExpanded: true,
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
                  // Role is fixed once the account exists — changing it is a
                  // distinct capability the spec reserves for
                  // Clinic Admin/Super Admin elsewhere, not this form.
                  items: AppConstants.staffRoles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(roleLabel(role)),
                        ),
                      )
                      .toList(),
                  onChanged: _isEdit
                      ? null
                      : (value) => setState(() => _role = value ?? _role),
                ),
                if (_isDoctor) ...[
                  const SizedBox(height: 16),
                  CliniqnovvaTextField(
                    label: 'Specialty',
                    controller: _specialtyController,
                    hint: 'e.g. Pediatrician',
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
                  widget.branchId == null
                      ? const SizedBox.shrink()
                      : Consumer(
                          builder: (context, ref, _) {
                            final departmentsAsync = ref.watch(
                              departmentsProvider(widget.branchId),
                            );
                            return departmentsAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text(
                                '$e',
                                style: const TextStyle(
                                  color: AppColors.errorRed,
                                ),
                              ),
                              data: (departments) => _DepartmentDropdown(
                                departments: departments,
                                value: _departmentId,
                                onChanged: (id) =>
                                    setState(() => _departmentId = id),
                              ),
                            );
                          },
                        ),
                ],
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Phone',
                  controller: _phoneController,
                  hint: '+250 7XX XXX XXX',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Email',
                  controller: _emailController,
                  hint: 'staff@clinic.rw',
                  keyboardType: TextInputType.emailAddress,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  CliniqnovvaTextField(
                    label: 'Password',
                    controller: _passwordController,
                    hint: 'Type one, or click Generate',
                    obscureText: _obscurePassword,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const AppIcon(AppIcons.generate, size: 18),
                          tooltip: 'Generate password',
                          onPressed: () => setState(() {
                            _passwordController.text = _generatePassword();
                            _obscurePassword = false;
                          }),
                        ),
                        IconButton(
                          icon: AppIcon(
                            _obscurePassword
                                ? AppIcons.view
                                : AppIcons.eyeSlash,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        'Select department (optional)',
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
              child: Text(d.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
