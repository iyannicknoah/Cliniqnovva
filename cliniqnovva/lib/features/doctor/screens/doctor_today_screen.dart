import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/row_actions_menu.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../appointments/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../patients/providers/patients_provider.dart';

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

/// Part 17 Task 2 — /doctor-today. Today's appointments for the signed-in
/// doctor only (their own `doctorId`, same auto-scoping already used in
/// `appointments_screen.dart`). Tapping a row opens the patient record
/// scoped exactly as Part 9 (full clinical access for a doctor — diagnosis/
/// prescription/notes). "Mark Complete" only ever appears once the
/// appointment is checked in — mirrors the server's own state machine
/// (Part 11), same as the general Appointments screen's action cell.
class DoctorTodayScreen extends ConsumerWidget {
  const DoctorTodayScreen({super.key});

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
          final doctorId = FirebaseService.currentUserId;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Today's Schedule",
                        style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const TopBarActions(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a patient to open their record.',
                  style: TextStyle(color: context.appSubtext, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: branchId == null || doctorId == null
                      ? const NoBranchSelectedState()
                      : _TodayList(branchId: branchId, doctorId: doctorId),
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
  const _TodayList({required this.branchId, required this.doctorId});

  final String branchId;
  final String doctorId;

  Future<void> _markComplete(BuildContext context, WidgetRef ref, AppointmentModel appt) async {
    try {
      final updated = await runWithFeedback(
        context,
        () => ref.read(appointmentsNotifierProvider.notifier).setStatus(appt.id, 'completed'),
        loadingMessage: 'Marking complete…',
        successMessage: 'Visit marked complete.',
      );
      if (updated.invoiceId != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Invoice created for this visit.'),
              duration: const Duration(seconds: 4),
            ),
          );
      }
    } catch (_) {
      // runWithFeedback already surfaced the reason.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(
      appointmentsListProvider((branchId: branchId, doctorId: doctorId, patientId: null, tab: 'today')),
    );

    return apptsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
      data: (appts) {
        final sorted = [...appts]..sort((a, b) => a.startTime.compareTo(b.startTime));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CliniqnovvaTableHeader(
              columns: ['Patient', 'Time', 'Status', 'Actions'],
              lastColumnEndPadding: 50,
            ),
            Expanded(
              child: sorted.isEmpty
                  ? Center(
                      child: Text(
                        'No appointments with you today — enjoy the quiet.',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    )
                  : ListView(
                      children: sorted
                          .map(
                            (appt) => CliniqnovvaTableRow(
                              lastColumnEndPadding: 50,
                              onTap: () => context.go('/patients/${appt.patientId}'),
                              cells: [
                                _PatientCell(patientId: appt.patientId),
                                Text('${appt.startTime}–${appt.endTime}', style: TextStyle(color: context.appText)),
                                StatusBadge(
                                  text: _statusLabels[appt.status] ?? appt.status,
                                  type: _badgeTypeFor(appt.status),
                                ),
                                RowActionsMenu(
                                  actions: appt.status == 'checkedIn'
                                      ? [
                                          RowAction(
                                            label: 'Mark Complete',
                                            onTap: () => _markComplete(context, ref, appt),
                                          ),
                                        ]
                                      : [],
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
