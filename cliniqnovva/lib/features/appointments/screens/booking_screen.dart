import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart';
import '../../departments/providers/services_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../../patients/providers/patients_provider.dart';
import '../../patients/screens/register_patient_screen.dart';
import '../../patients/widgets/patient_form_fields.dart';
import '../../staff/models/staff_model.dart';
import '../../staff/providers/staff_provider.dart';
import '../models/appointment_model.dart';
import '../providers/appointments_provider.dart';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Part 11 Task 1. 2026-08-15, explicit user instruction — switched from a
/// full routed page (`/appointments/book`) to the same centered modal
/// pattern as Register Patient/Patient Profile (`Material` +
/// `AppTheme.cardRadius` corners, fade+scale transition). Every booking,
/// regardless of who makes it, still goes through this dialog to POST
/// /api/appointments/book — the one shared booking endpoint (Task 5) a
/// future Patient App will reuse unchanged.
Future<void> showBookingPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Book Appointment',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const Center(child: _BookingPanel()),
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

class _BookingPanel extends ConsumerWidget {
  const _BookingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

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
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: claims.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(60),
              child: LoadingWidget(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e', style: TextStyle(color: context.appSubtext)),
            ),
            data: (data) {
              final role = data?['role'] as String?;
              final isOrgAdmin = role == AppConstants.roleClinicAdmin;
              final ownBranchId = data?['branchId'] as String?;
              return _BookingForm(
                branchId: isOrgAdmin ? null : ownBranchId,
                showBranchSelector: isOrgAdmin,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BookingForm extends ConsumerStatefulWidget {
  const _BookingForm({required this.branchId, required this.showBranchSelector});

  final String? branchId;
  final bool showBranchSelector;

  @override
  ConsumerState<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<_BookingForm> {
  String? _patientId;
  final _patientSearchController = TextEditingController();
  String _patientQuery = '';

  String? _departmentId;
  String? _serviceId;
  String? _doctorId;
  DateTime? _date;
  AppointmentSlot? _selectedSlot;

  bool _booking = false;
  String? _error;

  @override
  void dispose() {
    _patientSearchController.dispose();
    super.dispose();
  }

  void _resetDownstreamOfDepartment() {
    _serviceId = null;
    _doctorId = null;
    _selectedSlot = null;
  }

  void _resetDownstreamOfDoctorOrDate() {
    _selectedSlot = null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _resetDownstreamOfDoctorOrDate();
      });
    }
  }

  Future<void> _confirmBooking(String branchId) async {
    final patientId = _patientId;
    final serviceId = _serviceId;
    final doctorId = _doctorId;
    final date = _date;
    final slot = _selectedSlot;
    if (patientId == null ||
        serviceId == null ||
        doctorId == null ||
        date == null ||
        slot == null) {
      setState(() => _error = 'Complete every step before confirming.');
      return;
    }

    setState(() {
      _booking = true;
      _error = null;
    });

    final dateStr = _isoDate(date);

    try {
      final appointment = await ref
          .read(appointmentsNotifierProvider.notifier)
          .book(
            branchId: branchId,
            patientId: patientId,
            doctorId: doctorId,
            serviceId: serviceId,
            date: dateStr,
            startTime: slot.startTime,
            endTime: slot.endTime,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/appointments?justBooked=${appointment.id}');
    } catch (e) {
      if (!mounted) return;
      // Task 2: reject clearly and let the slot grid refresh — the
      // notifier already invalidated availableSlotsProvider, so clearing
      // the selection here just makes the now-stale pick visibly go away.
      setState(() {
        _booking = false;
        _selectedSlot = null;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBranchId =
        widget.branchId ?? ref.watch(activeBranchIdProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Book Appointment',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              IconButton(
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
              if (effectiveBranchId == null)
                Text(
                  'empty_pick_branch'.tr(),
                  style: TextStyle(color: context.appSubtext),
                )
              else ...[
                _SectionCard(
                  title: '1. Patient',
                  child: _patientId == null
                      ? _PatientPicker(
                          controller: _patientSearchController,
                          query: _patientQuery,
                          branchId: effectiveBranchId,
                          onQueryChanged: (v) =>
                              setState(() => _patientQuery = v),
                          onSelected: (id) => setState(() => _patientId = id),
                        )
                      : _SelectedPatient(
                          patientId: _patientId!,
                          onChange: () => setState(() {
                            _patientId = null;
                            _patientSearchController.clear();
                            _patientQuery = '';
                          }),
                        ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: '2. Department & Service',
                  child: _DepartmentAndService(
                    branchId: effectiveBranchId,
                    departmentId: _departmentId,
                    serviceId: _serviceId,
                    onDepartmentChanged: (id) => setState(() {
                      _departmentId = id;
                      _resetDownstreamOfDepartment();
                    }),
                    onServiceChanged: (id) => setState(() {
                      _serviceId = id;
                      _resetDownstreamOfDoctorOrDate();
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                if (_departmentId != null)
                  _SectionCard(
                    title: '3. Doctor',
                    child: _DoctorPicker(
                      branchId: effectiveBranchId,
                      departmentId: _departmentId!,
                      doctorId: _doctorId,
                      selectedDate: _date,
                      onChanged: (id) => setState(() {
                        _doctorId = id;
                        _resetDownstreamOfDoctorOrDate();
                      }),
                      onDaySelected: (date) => setState(() {
                        _date = date;
                        _resetDownstreamOfDoctorOrDate();
                      }),
                    ),
                  ),
                if (_doctorId != null) ...[
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: '4. Date & Time',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(
                            AppTheme.inputRadius,
                          ),
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: context.appBorder),
                              borderRadius: BorderRadius.circular(
                                AppTheme.inputRadius,
                              ),
                            ),
                            child: Text(
                              _date == null ? 'Pick a date' : _isoDate(_date!),
                              style: TextStyle(
                                color: _date == null
                                    ? context.appSubtext
                                    : context.appText,
                              ),
                            ),
                          ),
                        ),
                        if (_date != null && _serviceId != null) ...[
                          const SizedBox(height: 16),
                          _SlotGrid(
                            branchId: effectiveBranchId,
                            doctorId: _doctorId!,
                            serviceId: _serviceId!,
                            date: _isoDate(_date!),
                            selected: _selectedSlot,
                            onSelected: (slot) =>
                                setState(() => _selectedSlot = slot),
                          ),
                        ],
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
                SizedBox(
                  width: 220,
                  child: CliniqnovvaButton(
                    label: 'Confirm Booking',
                    isLoading: _booking,
                    onPressed: (_booking || _selectedSlot == null)
                        ? null
                        : () => _confirmBooking(effectiveBranchId),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.appText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PatientPicker extends ConsumerWidget {
  const _PatientPicker({
    required this.controller,
    required this.query,
    required this.branchId,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String query;
  final String branchId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CliniqnovvaTextField(
                label: 'Search',
                controller: controller,
                hint: 'Name, phone, or National ID',
                onChanged: onQueryChanged,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 170,
              child: CliniqnovvaButton.text(
                label: '+ Register new',
                // 2026-08-15 — Register Patient is a dialog too now, so this
                // just nests it on top of the booking dialog and gets the
                // new patient id back directly instead of round-tripping
                // through a route (`returnTo` no longer exists).
                onPressed: () async {
                  final patientId = await showRegisterPatientPanel(
                    context,
                    returnPatientId: true,
                  );
                  if (patientId != null) onSelected(patientId);
                },
              ),
            ),
          ],
        ),
        if (query.isNotEmpty) ...[
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final resultsAsync = ref.watch(
                patientsSearchProvider((branchId: branchId, query: query)),
              );
              return resultsAsync.when(
                loading: () => const LoadingWidget(),
                error: (e, _) =>
                    Text('$e', style: TextStyle(color: context.appSubtext)),
                data: (results) => results.isEmpty
                    ? Text(
                        'No matches.',
                        style: TextStyle(color: context.appSubtext),
                      )
                    : Column(
                        children: results
                            .map(
                              (p) => InkWell(
                                onTap: () => onSelected(p.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                      ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SelectedPatient extends ConsumerWidget {
  const _SelectedPatient({required this.patientId, required this.onChange});

  final String patientId;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    return patientAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (patient) => Row(
        children: [
          AvatarWidget(firstName: patient.name, size: 36),
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
          CliniqnovvaButton.text(
            label: 'Change',
            color: context.appSubtext,
            onPressed: onChange,
          ),
        ],
      ),
    );
  }
}

class _DepartmentAndService extends ConsumerWidget {
  const _DepartmentAndService({
    required this.branchId,
    required this.departmentId,
    required this.serviceId,
    required this.onDepartmentChanged,
    required this.onServiceChanged,
  });

  final String branchId;
  final String? departmentId;
  final String? serviceId;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onServiceChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsProvider(branchId));

    return departmentsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (departments) {
        final active = departments.where((d) => d.isActive).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabeledDropdown(
              label: 'Department',
              value: departmentId,
              hint: 'Select department',
              items: active.map((d) => d.id).toList(),
              itemLabels: {for (final d in active) d.id: d.name},
              onChanged: onDepartmentChanged,
            ),
            if (departmentId != null) ...[
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final servicesAsync = ref.watch(servicesProvider(branchId));
                  return servicesAsync.when(
                    loading: () => const LoadingWidget(),
                    error: (e, _) =>
                        Text('$e', style: TextStyle(color: context.appSubtext)),
                    data: (services) {
                      final options = services
                          .where(
                            (s) => s.departmentId == departmentId && s.isActive,
                          )
                          .toList();
                      final selected = options
                          .where((s) => s.id == serviceId)
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LabeledDropdown(
                            label: 'Service',
                            value: serviceId,
                            hint: options.isEmpty
                                ? 'No services in this department'
                                : 'Select service',
                            items: options.map((s) => s.id).toList(),
                            itemLabels: {for (final s in options) s.id: s.name},
                            onChanged: onServiceChanged,
                          ),
                          if (selected.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${selected.first.defaultDurationMins} mins · '
                              '${selected.first.defaultPriceRwf} RWF',
                              style: TextStyle(
                                color: context.appSubtext,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

const _weekdayOrder = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const _weekdayShortLabels = {
  'monday': 'Mon',
  'tuesday': 'Tue',
  'wednesday': 'Wed',
  'thursday': 'Thu',
  'friday': 'Fri',
  'saturday': 'Sat',
  'sunday': 'Sun',
};

/// The next date (today included) that falls on [day] ('monday'..'sunday').
DateTime _nextDateForWeekday(String day) {
  final targetIndex = _weekdayOrder.indexOf(day);
  if (targetIndex == -1) return DateTime.now();
  final now = DateTime.now();
  final diff = (targetIndex - (now.weekday - 1) + 7) % 7;
  return DateTime(now.year, now.month, now.day + diff);
}

/// 2026-08-15, explicit user instruction — once a doctor is picked, ALL of
/// their slots show right under the search field: not a single date's
/// bookable grid (which reads as broken on a day they don't work at all —
/// the exact complaint that led to this fix), but every entry in
/// [StaffModel.schedule], their actual recurring weekly availability.
/// Tapping a day is a shortcut that jumps [selectedDate] to its next
/// occurrence (today if today qualifies) via [onDaySelected] — step 4's
/// grid then shows that day's real bookable slots (service duration,
/// existing bookings, and blocked time all factored in, same as always).
class _DoctorPicker extends ConsumerWidget {
  const _DoctorPicker({
    required this.branchId,
    required this.departmentId,
    required this.doctorId,
    required this.selectedDate,
    required this.onChanged,
    required this.onDaySelected,
  });

  final String branchId;
  final String departmentId;
  final String? doctorId;
  final DateTime? selectedDate;
  final ValueChanged<String?> onChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider(branchId));
    return staffAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (staff) {
        final doctors = staff
            .where(
              (s) =>
                  s.role == AppConstants.roleDoctor &&
                  s.departmentIds.contains(departmentId),
            )
            .toList();
        if (doctors.isEmpty) {
          return Text(
            'No doctors in this department.',
            style: TextStyle(color: context.appSubtext),
          );
        }
        StaffModel? selectedDoctor;
        for (final d in doctors) {
          if (d.id == doctorId) {
            selectedDoctor = d;
            break;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchableDropdown(
              label: 'Doctor',
              value: doctorId,
              hint: 'Select doctor',
              items: doctors.map((d) => d.id).toList(),
              itemLabels: {for (final d in doctors) d.id: d.name},
              // 2026-08-15, explicit user instruction — specialty shown on
              // the right of each option so admins/receptionists can tell
              // doctors sharing a department apart at a glance.
              itemSubLabels: {
                for (final d in doctors) d.id: d.specialty ?? '',
              },
              onChanged: onChanged,
            ),
            if (selectedDoctor != null) ...[
              const SizedBox(height: 16),
              Text(
                'Weekly schedule',
                style: TextStyle(
                  color: context.appSubtext,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final entries = [...selectedDoctor!.schedule]
                    ..sort(
                      (a, b) => _weekdayOrder
                          .indexOf(a.day)
                          .compareTo(_weekdayOrder.indexOf(b.day)),
                    );
                  if (entries.isEmpty) {
                    return Text(
                      'No weekly schedule set for this doctor yet.',
                      style: TextStyle(color: context.appSubtext),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entries.map((entry) {
                      final entryDate = _nextDateForWeekday(entry.day);
                      final isSelected =
                          selectedDate != null &&
                          _isoDate(selectedDate!) == _isoDate(entryDate);
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onDaySelected(entryDate),
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
                            '${_weekdayShortLabels[entry.day] ?? entry.day} · '
                            '${entry.startTime}–${entry.endTime}',
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
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SlotGrid extends ConsumerWidget {
  const _SlotGrid({
    required this.branchId,
    required this.doctorId,
    required this.serviceId,
    required this.date,
    required this.selected,
    required this.onSelected,
  });

  final String branchId;
  final String doctorId;
  final String serviceId;
  final String date;
  final AppointmentSlot? selected;
  final ValueChanged<AppointmentSlot> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(
      availableSlotsProvider((
        doctorId: doctorId,
        branchId: branchId,
        serviceId: serviceId,
        date: date,
      )),
    );

    return slotsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (slots) {
        if (slots.isEmpty) {
          return Text(
            'No available slots that day — try another date.',
            style: TextStyle(color: context.appSubtext),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isSelected =
                selected?.startTime == slot.startTime &&
                selected?.endTime == slot.endTime;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelected(slot),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? context.appPrimary : context.appCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? context.appPrimary : context.appBorder,
                  ),
                ),
                child: Text(
                  slot.startTime,
                  style: TextStyle(
                    color: isSelected
                        ? (context.isDark ? Colors.black : Colors.white)
                        : context.appText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
