import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../providers/patients_provider.dart';
import 'patient_profile_screen.dart';
import 'register_patient_screen.dart';

const _monthAbbr = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime d) => '${_monthAbbr[d.month]} ${d.day}, ${d.year}';

/// Part 9 Task 1 — /patients. All patients in this web-only build are
/// registered by front-desk staff (registeredVia: 'walkIn'); this screen
/// is how staff find an existing one or start a new registration.
class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final canRegister = [
            AppConstants.roleReceptionist,
            AppConstants.roleBranchAdmin,
            AppConstants.roleClinicAdmin,
          ].contains(role);
          final canMerge = [
            AppConstants.roleBranchAdmin,
            AppConstants.roleClinicAdmin,
          ].contains(role);

          return _PatientsBody(
            branchId: isOrgAdmin ? null : ownBranchId,
            showBranchSelector: isOrgAdmin,
            canRegister: canRegister,
            canMerge: canMerge,
            searchController: _searchController,
            query: _query,
            onQueryChanged: (value) => setState(() => _query = value),
          );
        },
      ),
    );
  }
}

class _PatientsBody extends ConsumerWidget {
  const _PatientsBody({
    required this.branchId,
    required this.showBranchSelector,
    required this.canRegister,
    required this.canMerge,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
  });

  final String? branchId;
  final bool showBranchSelector;
  final bool canRegister;
  final bool canMerge;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveBranchId = branchId ?? ref.watch(activeBranchIdProvider);
    final isAllBranches = branchId == null && ref.watch(showAllBranchesProvider);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Patients',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              if (canMerge) ...[
                CliniqnovvaButton.text(
                  label: 'Merge Patients',
                  color: context.appText,
                  onPressed: () => context.go('/patients/merge'),
                ),
                const SizedBox(width: 4),
              ],
              if (canRegister) ...[
                CliniqnovvaButton(
                  label: '+ Register Patient',
                  onPressed: () => showRegisterPatientPanel(context),
                ),
                const SizedBox(width: 12),
              ],
              const TopBarActions(),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 360,
            child: CliniqnovvaTextField(
              label: 'Search',
              controller: searchController,
              hint: 'Name, phone, or National ID',
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: effectiveBranchId == null && !isAllBranches
                ? const NoBranchSelectedState()
                : _PatientsList(
                    branchId: isAllBranches ? null : effectiveBranchId,
                    query: query,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientsList extends ConsumerWidget {
  const _PatientsList({required this.branchId, required this.query});

  final String? branchId;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(
      patientsSearchProvider((branchId: branchId, query: query)),
    );

    return patientsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (patients) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CliniqnovvaTableHeader(
            columns: ['Patient', 'Phone', 'Last visit'],
            // 2026-08-14, explicit user instruction — 150px right padding
            // on this table's last column (label + row content), same
            // mechanism as the Actions-column padding elsewhere but a
            // different table/column and a different pixel value.
            lastColumnEndPadding: 150,
          ),
          Expanded(
            child: patients.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No patients registered yet.'
                          : 'No patients match "$query".',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  )
                : ListView(
                    children: patients
                        .map(
                          (patient) => CliniqnovvaTableRow(
                            lastColumnEndPadding: 150,
                            onTap: () =>
                                showPatientProfilePanel(context, id: patient.id),
                            cells: [
                              Text(
                                patient.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.appText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                patient.phone,
                                style: TextStyle(color: context.appText),
                              ),
                              Text(
                                patient.lastVisitDate != null
                                    ? _formatDate(patient.lastVisitDate!)
                                    : 'No visits yet',
                                style: TextStyle(
                                  color: patient.lastVisitDate != null
                                      ? context.appText
                                      : context.appSubtext,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
