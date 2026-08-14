import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../models/patient_model.dart';
import '../providers/patients_provider.dart';

/// Part 10 Task 2 — /patients/merge, Branch Admin/Clinic Admin only
/// (enforced again server-side — this screen's own role gate is defense in
/// depth, not the real boundary). Pick two records, preview both side by
/// side, choose which survives; the other is reassigned into it and
/// deactivated, never deleted.
class MergePatientsScreen extends ConsumerWidget {
  const MergePatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.appSubtext)),
        ),
        data: (data) {
          final role = data?['role'] as String?;
          final allowed = [
            AppConstants.roleBranchAdmin,
            AppConstants.roleClinicAdmin,
          ].contains(role);
          if (!allowed) {
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'Merging patients is restricted to Branch Admins and Clinic Admins.',
                style: TextStyle(color: context.appSubtext),
              ),
            );
          }

          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final ownBranchId = data?['branchId'] as String?;
          return _MergeBody(
            branchId: isOrgAdmin ? null : ownBranchId,
            showBranchSelector: isOrgAdmin,
          );
        },
      ),
    );
  }
}

class _MergeBody extends ConsumerStatefulWidget {
  const _MergeBody({required this.branchId, required this.showBranchSelector});

  final String? branchId;
  final bool showBranchSelector;

  @override
  ConsumerState<_MergeBody> createState() => _MergeBodyState();
}

class _MergeBodyState extends ConsumerState<_MergeBody> {
  String? _patientAId;
  String? _patientBId;
  String? _survivorId;
  bool _merging = false;
  String? _error;

  Future<void> _confirmAndMerge(PatientModel a, PatientModel b) async {
    final survivorId = _survivorId;
    if (survivorId == null) {
      setState(() => _error = 'Choose which record should survive.');
      return;
    }
    final surviving = survivorId == a.id ? a : b;
    final merged = survivorId == a.id ? b : a;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Merge these patients?'),
        content: Text(
          '${merged.name}\'s appointments, medical records, and invoices will move to '
          '${surviving.name}. ${merged.name}\'s record will be deactivated (not deleted). '
          'This cannot be undone from here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _merging = true;
      _error = null;
    });

    try {
      final result = await runWithFeedback(
        context,
        () => ref.read(patientsNotifierProvider.notifier).mergePatients(
          survivingPatientId: surviving.id,
          mergedPatientId: merged.id,
        ),
        loadingMessage: 'Merging…',
        successMessage: 'Patients merged.',
      );
      if (!mounted) return;
      context.go('/patients/${result.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _merging = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBranchId = widget.branchId ?? ref.watch(activeBranchIdProvider);
    final isAllBranches = widget.branchId == null && ref.watch(showAllBranchesProvider);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merge Patients',
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find the two duplicate records, compare them, and choose which one survives.',
                      style: TextStyle(color: context.appSubtext, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (widget.showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              const TopBarActions(),
            ],
          ),
          const SizedBox(height: 28),
          if (effectiveBranchId == null && !isAllBranches)
            Text(
              'empty_pick_branch'.tr(),
              style: TextStyle(color: context.appSubtext),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PatientSlot(
                        label: 'Record A',
                        branchId: isAllBranches ? null : effectiveBranchId,
                        selectedId: _patientAId,
                        excludeId: _patientBId,
                        onSelected: (id) => setState(() {
                          _patientAId = id;
                          if (_survivorId != null &&
                              _survivorId != _patientAId &&
                              _survivorId != _patientBId) {
                            _survivorId = null;
                          }
                        }),
                        onClear: () => setState(() {
                          _patientAId = null;
                          _survivorId = null;
                        }),
                        survivorId: _survivorId,
                        onChooseSurvivor: (id) =>
                            setState(() => _survivorId = id),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _PatientSlot(
                        label: 'Record B',
                        branchId: isAllBranches ? null : effectiveBranchId,
                        selectedId: _patientBId,
                        excludeId: _patientAId,
                        onSelected: (id) => setState(() {
                          _patientBId = id;
                          if (_survivorId != null &&
                              _survivorId != _patientAId &&
                              _survivorId != _patientBId) {
                            _survivorId = null;
                          }
                        }),
                        onClear: () => setState(() {
                          _patientBId = null;
                          _survivorId = null;
                        }),
                        survivorId: _survivorId,
                        onChooseSurvivor: (id) =>
                            setState(() => _survivorId = id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.pillRedBg,
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.pillRedText, fontSize: 13),
              ),
            ),
          ],
          if (_patientAId != null && _patientBId != null) ...[
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, _) {
                final aAsync = ref.watch(patientDetailProvider(_patientAId!));
                final bAsync = ref.watch(patientDetailProvider(_patientBId!));
                final a = aAsync.valueOrNull;
                final b = bAsync.valueOrNull;
                return SizedBox(
                  width: 180,
                  child: CliniqnovvaButton(
                    label: 'Merge',
                    isLoading: _merging,
                    onPressed: (_merging || a == null || b == null)
                        ? null
                        : () => _confirmAndMerge(a, b),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PatientSlot extends ConsumerStatefulWidget {
  const _PatientSlot({
    required this.label,
    required this.branchId,
    required this.selectedId,
    required this.excludeId,
    required this.onSelected,
    required this.onClear,
    required this.survivorId,
    required this.onChooseSurvivor,
  });

  final String label;
  final String? branchId;
  final String? selectedId;
  final String? excludeId;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;
  final String? survivorId;
  final ValueChanged<String> onChooseSurvivor;

  @override
  ConsumerState<_PatientSlot> createState() => _PatientSlotState();
}

class _PatientSlotState extends ConsumerState<_PatientSlot> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: widget.selectedId == null
          ? _buildSearch(context)
          : _buildSelected(context, widget.selectedId!),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: context.appText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        CliniqnovvaTextField(
          label: 'Search',
          controller: _searchController,
          hint: 'Name, phone, or National ID',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        if (_query.isNotEmpty)
          Consumer(
            builder: (context, ref, _) {
              final resultsAsync = ref.watch(
                patientsSearchProvider((
                  branchId: widget.branchId,
                  query: _query,
                )),
              );
              return resultsAsync.when(
                loading: () => const LoadingWidget(),
                error: (e, _) =>
                    Text('$e', style: TextStyle(color: context.appSubtext)),
                data: (results) {
                  final filtered = results
                      .where((p) => p.id != widget.excludeId)
                      .toList();
                  if (filtered.isEmpty) {
                    return Text(
                      'No matches.',
                      style: TextStyle(color: context.appSubtext),
                    );
                  }
                  return Column(
                    children: filtered
                        .map(
                          (p) => InkWell(
                            onTap: () => widget.onSelected(p.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  AvatarWidget(firstName: p.name, size: 28),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            color: context.appText,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          p.phone,
                                          style: TextStyle(
                                            color: context.appSubtext,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildSelected(BuildContext context, String id) {
    final patientAsync = ref.watch(patientDetailProvider(id));

    return patientAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (patient) {
        final isSurvivor = widget.survivorId == id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CliniqnovvaButton.text(
                  label: 'Change',
                  color: context.appSubtext,
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _query = '';
                    });
                    widget.onClear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AvatarWidget(firstName: patient.name, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: TextStyle(
                          color: context.appText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        patient.phone,
                        style: TextStyle(color: context.appSubtext, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CountRow(
              label: 'Medical records',
              value: patient.medicalRecords?.length,
            ),
            _CountRow(label: 'Appointments', value: patient.appointmentCount),
            _CountRow(label: 'Invoices', value: patient.invoiceCount),
            _CountRow(label: 'Documents', value: patient.documents?.length),
            if (patient.nationalId != null)
              _CountRow(label: 'National ID', text: patient.nationalId),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CliniqnovvaButton(
                label: isSurvivor ? 'Will survive' : 'Keep this record',
                color: isSurvivor ? context.appPrimary : null,
                onPressed: () => widget.onChooseSurvivor(id),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, this.value, this.text});

  final String label;
  final int? value;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.appSubtext, fontSize: 13),
            ),
          ),
          Text(
            text ?? '${value ?? 0}',
            style: TextStyle(
              color: context.appText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
