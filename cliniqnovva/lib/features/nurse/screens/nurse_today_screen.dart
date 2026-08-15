import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../patients/providers/patients_provider.dart';
import '../../patients/screens/patient_profile_screen.dart';

const _statusLabels = {
  'pending': 'Pending',
  'confirmed': 'Confirmed',
  'checkedIn': 'Checked In',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
};

BadgeType _badgeTypeFor(String status) => switch (status) {
  'completed' => BadgeType.success,
  'cancelled' => BadgeType.error,
  'confirmed' || 'checkedIn' => BadgeType.info,
  _ => BadgeType.warning,
};

/// Part 17 Task 3 — /nurse-today. A nurse supports the whole branch, not
/// one doctor (appointments have no `nurseId` field to filter by), so this
/// shows every one of TODAY's branch appointments — not just one doctor's.
/// Tapping a row opens the patient record, scoped exactly as Part 9: read +
/// vitals-only, the same restriction `patient_profile_screen.dart` already
/// enforces for the nurse role (no diagnosis/prescription fields exposed).
class NurseTodayScreen extends ConsumerWidget {
  const NurseTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          final branchId = data?['branchId'] as String?;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Today's Patients",
                        style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const TopBarActions(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a patient to record vitals.',
                  style: TextStyle(color: context.appSubtext, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: branchId == null
                      ? const NoBranchSelectedState()
                      : _TodayList(branchId: branchId),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodayList extends ConsumerWidget {
  const _TodayList({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(
      appointmentsListProvider((branchId: branchId, doctorId: null, patientId: null, tab: 'today')),
    );

    return apptsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
      data: (appts) {
        final sorted = [...appts]..sort((a, b) => a.startTime.compareTo(b.startTime));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CliniqnovvaTableHeader(columns: ['Patient', 'Time', 'Status']),
            Expanded(
              child: sorted.isEmpty
                  ? Center(
                      child: Text(
                        'No patients booked today yet — check back later.',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    )
                  : ListView(
                      children: sorted
                          .map(
                            (appt) => CliniqnovvaTableRow(
                              onTap: () => showPatientProfilePanel(
                                context,
                                id: appt.patientId,
                              ),
                              cells: [
                                _PatientCell(patientId: appt.patientId),
                                Text('${appt.startTime}–${appt.endTime}', style: TextStyle(color: context.appText)),
                                StatusBadge(
                                  text: _statusLabels[appt.status] ?? appt.status,
                                  type: _badgeTypeFor(appt.status),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PatientCell extends ConsumerWidget {
  const _PatientCell({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    return patientAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('—', style: TextStyle(color: context.appSubtext)),
      data: (patient) => Text(
        patient.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
      ),
    );
  }
}
