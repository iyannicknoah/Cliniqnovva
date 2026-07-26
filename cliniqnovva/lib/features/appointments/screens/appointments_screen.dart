import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/row_actions_menu.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../../patients/providers/patients_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../models/appointment_model.dart';
import '../providers/appointments_provider.dart';

const _tabLabels = ['Today', 'Upcoming', 'History'];
const _tabKeys = ['today', 'upcoming', 'history'];

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

String _kigaliToday() {
  final d = DateTime.now().toUtc().add(const Duration(hours: 2));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Part 11 Task 3/4 — /appointments. Today/Upcoming/History tabs, the
/// full status action set, and a "Now Serving #N" queue display for
/// reception.
class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() =>
      _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  int _tab = 0;

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
          final isDoctor = role == AppConstants.roleDoctor;
          final ownBranchId = data?['branchId'] as String?;
          final canManage = [
            AppConstants.roleReceptionist,
            AppConstants.roleBranchAdmin,
            AppConstants.roleClinicAdmin,
          ].contains(role);

          return _AppointmentsBody(
            branchId: isOrgAdmin ? null : ownBranchId,
            showBranchSelector: isOrgAdmin,
            doctorId: isDoctor ? FirebaseService.currentUserId : null,
            canManage: canManage,
            tab: _tab,
            onTabChanged: (i) => setState(() => _tab = i),
          );
        },
      ),
    );
  }
}

class _AppointmentsBody extends ConsumerWidget {
  const _AppointmentsBody({
    required this.branchId,
    required this.showBranchSelector,
    required this.doctorId,
    required this.canManage,
    required this.tab,
    required this.onTabChanged,
  });

  final String? branchId;
  final bool showBranchSelector;
  final String? doctorId;
  final bool canManage;
  final int tab;
  final ValueChanged<int> onTabChanged;

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
                  'Appointments',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              if (canManage)
                SizedBox(
                  width: 170,
                  child: CliniqnovvaButton(
                    label: '+ Book Appointment',
                    onPressed: () => context.go('/appointments/book'),
                  ),
                ),
            ],
          ),
          if (effectiveBranchId != null && doctorId == null) ...[
            const SizedBox(height: 20),
            _QueueBanner(branchId: effectiveBranchId),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: 320,
            child: SegmentedTabs(
              labels: _tabLabels,
              index: tab,
              onChanged: onTabChanged,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: effectiveBranchId == null && !isAllBranches
                ? const NoBranchSelectedState()
                : AppointmentsList(
                    branchId: isAllBranches ? null : effectiveBranchId,
                    doctorId: doctorId,
                    tab: _tabKeys[tab],
                    canManage: canManage,
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueBanner extends ConsumerWidget {
  const _QueueBanner({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(
      queueDisplayProvider((branchId: branchId, date: _kigaliToday())),
    );

    return queueAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (queue) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: context.cardDeco(),
        child: Row(
          children: [
            Text(
              'Now Serving',
              style: TextStyle(color: context.appSubtext, fontSize: 13),
            ),
            const SizedBox(width: 10),
            Text(
              queue.nowServingNumber != null ? '#${queue.nowServingNumber}' : '—',
              style: TextStyle(
                color: context.appText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 24),
            Text(
              '${queue.waitingCount} waiting',
              style: TextStyle(color: context.appSubtext, fontSize: 13),
            ),
            if (queue.lastCompletedNumber != null) ...[
              const SizedBox(width: 24),
              Text(
                'Last completed: #${queue.lastCompletedNumber}',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Patient/Doctor/Date & time/Status/Actions table — the same one the
/// Appointments screen's Today/Upcoming/History tabs use. Public (2026-07-25)
/// so the Dashboard's "Today's Appointments" section can reuse it verbatim
/// instead of the old compact time+name+status-dot list, giving Clinic
/// Admin/Branch Admin/Receptionist the same Confirm/Reschedule/Cancel
/// actions right from the dashboard.
class AppointmentsList extends ConsumerWidget {
  const AppointmentsList({
    super.key,
    required this.branchId,
    required this.doctorId,
    required this.tab,
    required this.canManage,
    this.embedded = false,
  });

  final String? branchId;
  final String? doctorId;
  final String tab;
  final bool canManage;

  /// True when embedded in a page that already scrolls as a whole (e.g. the
  /// Dashboard) — renders a plain, non-scrolling `Column` of rows instead of
  /// `Expanded`+`ListView`, which would otherwise need a bounded-height
  /// ancestor the Dashboard's `SingleChildScrollView` doesn't provide.
  final bool embedded;

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appt,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: const Text(
          'This frees the slot for someone else to book. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await runWithFeedback(
      context,
      () => ref
          .read(appointmentsNotifierProvider.notifier)
          .setStatus(appt.id, 'cancelled'),
      loadingMessage: 'Cancelling…',
      successMessage: 'Appointment cancelled.',
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appt,
    String status,
    String loadingMessage,
    String successMessage,
  ) async {
    try {
      final updated = await runWithFeedback(
        context,
        () => ref
            .read(appointmentsNotifierProvider.notifier)
            .setStatus(appt.id, status),
        loadingMessage: loadingMessage,
        successMessage: successMessage,
      );
      // Part 12 Task 1 — marking complete auto-generates an invoice
      // server-side; surface it here so staff can jump straight to billing
      // instead of having to go find it from the Billing list.
      if (updated.invoiceId != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Invoice created for this visit.'),
              action: SnackBarAction(
                label: 'View Invoice',
                onPressed: () => context.go('/billing/${updated.invoiceId}'),
              ),
              duration: const Duration(seconds: 6),
            ),
          );
      }
    } catch (_) {
      // runWithFeedback already surfaced the server's reason in the error SnackBar.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(
      appointmentsListProvider((
        branchId: branchId,
        doctorId: doctorId,
        patientId: null,
        tab: tab,
      )),
    );

    return apptsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (appts) {
        final sorted = [...appts]..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.startTime.compareTo(b.startTime);
        });

        final rows = sorted
            .map(
              (appt) => CliniqnovvaTableRow(
                cells: [
                  _PatientCell(patientId: appt.patientId),
                  _DoctorCell(doctorId: appt.doctorId),
                  Text(
                    '${appt.date} · ${appt.startTime}–${appt.endTime}',
                    style: TextStyle(color: context.appText),
                  ),
                  StatusBadge(
                    text: _statusLabels[appt.status] ?? appt.status,
                    type: _badgeTypeFor(appt.status),
                  ),
                  canManage || appt.status == 'checkedIn'
                      ? _ActionsCell(
                          appointment: appt,
                          canManage: canManage,
                          onConfirm: () => _setStatus(
                            context,
                            ref,
                            appt,
                            'confirmed',
                            'Confirming…',
                            'Appointment confirmed.',
                          ),
                          onCheckIn: () => _setStatus(
                            context,
                            ref,
                            appt,
                            'checkedIn',
                            'Checking in…',
                            'Patient checked in.',
                          ),
                          onComplete: () => _setStatus(
                            context,
                            ref,
                            appt,
                            'completed',
                            'Marking complete…',
                            'Appointment completed.',
                          ),
                          onCancel: () => _confirmCancel(context, ref, appt),
                          onReschedule: () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _RescheduleDialog(appointment: appt),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            )
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: embedded ? MainAxisSize.min : MainAxisSize.max,
          children: [
            const CliniqnovvaTableHeader(
              columns: ['Patient', 'Doctor', 'Date & time', 'Status', 'Actions'],
            ),
            if (embedded)
              sorted.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No appointments here.',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    )
                  : Column(children: rows)
            else
              Expanded(
                child: sorted.isEmpty
                    ? Center(
                        child: Text(
                          'No appointments here.',
                          style: TextStyle(color: context.appSubtext),
                        ),
                      )
                    : ListView(children: rows),
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

class _DoctorCell extends ConsumerWidget {
  const _DoctorCell({required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(staffDetailProvider(doctorId));
    return doctorAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('—', style: TextStyle(color: context.appSubtext)),
      data: (doctor) => Text(
        doctor.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.appText),
      ),
    );
  }
}

class _ActionsCell extends StatelessWidget {
  const _ActionsCell({
    required this.appointment,
    required this.canManage,
    required this.onConfirm,
    required this.onCheckIn,
    required this.onComplete,
    required this.onCancel,
    required this.onReschedule,
  });

  final AppointmentModel appointment;
  final bool canManage;
  final VoidCallback onConfirm;
  final VoidCallback onCheckIn;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    // Mark Complete only enabled after Check-In (Part 11 Task 3 DONE
    // CONDITION) — this mirrors the server's state machine exactly, so the
    // action is simply absent rather than present-but-disabled whenever
    // that transition isn't legal yet.
    final actions = <RowAction>[];
    switch (appointment.status) {
      case 'pending':
        if (canManage) {
          actions.add(RowAction(label: 'Confirm', onTap: onConfirm));
          actions.add(RowAction(label: 'Reschedule', onTap: onReschedule));
          actions.add(RowAction(label: 'Cancel', isDestructive: true, onTap: onCancel));
        }
      case 'confirmed':
        if (canManage) {
          actions.add(RowAction(label: 'Check-In', onTap: onCheckIn));
          actions.add(RowAction(label: 'Reschedule', onTap: onReschedule));
          actions.add(RowAction(label: 'Cancel', isDestructive: true, onTap: onCancel));
        }
      case 'checkedIn':
        actions.add(RowAction(label: 'Mark Complete', onTap: onComplete));
        if (canManage) {
          actions.add(RowAction(label: 'Cancel', isDestructive: true, onTap: onCancel));
        }
      default:
        break;
    }

    return RowActionsMenu(actions: actions);
  }
}

class _RescheduleDialog extends ConsumerStatefulWidget {
  const _RescheduleDialog({required this.appointment});

  final AppointmentModel appointment;

  @override
  ConsumerState<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends ConsumerState<_RescheduleDialog> {
  DateTime? _date;
  AppointmentSlot? _selectedSlot;
  bool _saving = false;
  String? _error;

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(widget.appointment.date) ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _confirm() async {
    final slot = _selectedSlot;
    if (slot == null) {
      setState(() => _error = 'Pick a new date and time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(appointmentsNotifierProvider.notifier).reschedule(
        widget.appointment.id,
        date: _isoDate(_date!),
        startTime: slot.startTime,
        endTime: slot.endTime,
      );
      if (!mounted) return;
      Navigator.pop(context);
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
      title: const Text('Reschedule appointment'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: context.appBorder),
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                ),
                child: Text(
                  _date == null ? 'Pick a new date' : _isoDate(_date!),
                  style: TextStyle(
                    color: _date == null ? context.appSubtext : context.appText,
                  ),
                ),
              ),
            ),
            if (_date != null) ...[
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final slotsAsync = ref.watch(
                    availableSlotsProvider((
                      doctorId: widget.appointment.doctorId,
                      branchId: widget.appointment.branchId,
                      serviceId: widget.appointment.serviceId,
                      date: _isoDate(_date!),
                    )),
                  );
                  return slotsAsync.when(
                    loading: () => const LoadingWidget(),
                    error: (e, _) => Text(
                      '$e',
                      style: TextStyle(color: context.appSubtext),
                    ),
                    data: (slots) => slots.isEmpty
                        ? Text(
                            'No slots that day.',
                            style: TextStyle(color: context.appSubtext),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: slots.map((slot) {
                              final isSelected =
                                  _selectedSlot?.startTime == slot.startTime;
                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    setState(() => _selectedSlot = slot),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.appPrimary
                                        : context.appCard,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? context.appPrimary
                                          : context.appBorder,
                                    ),
                                  ),
                                  child: Text(
                                    slot.startTime,
                                    style: TextStyle(
                                      color: isSelected
                                          ? (context.isDark
                                                ? Colors.black
                                                : Colors.white)
                                          : context.appText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  );
                },
              ),
            ],
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _confirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
