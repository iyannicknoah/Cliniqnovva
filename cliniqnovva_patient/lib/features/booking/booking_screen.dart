import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../browse/models/doctor_summary.dart';
import '../browse/providers/browse_provider.dart';
import 'models/appointment_model.dart';
import 'models/department_model.dart';
import 'models/service_model.dart';
import 'models/slot_model.dart';
import 'providers/booking_provider.dart';
import 'widgets/booking_chip.dart';
import 'widgets/date_strip_picker.dart';
import 'widgets/slot_chip_picker.dart';

/// Pushed on top of the shell (Part 19 Task 6). Part 21 Task 1: department
/// → service → doctor (skipped if pre-selected) → date → slot → confirm,
/// against the SAME available-slots/book endpoints the web dashboard's
/// Receptionist booking already uses — see providers/booking_provider.dart.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.branchId, this.doctorId});

  final String branchId;
  final String? doctorId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  String? _departmentId;
  String? _serviceId;
  late String? _doctorId = widget.doctorId;
  late DateTime _date = DateTime.now();
  SlotModel? _slot;

  void _resetBelowDepartment() {
    _serviceId = null;
    if (widget.doctorId == null) _doctorId = null;
    _slot = null;
  }

  void _resetBelowService() {
    if (widget.doctorId == null) _doctorId = null;
    _slot = null;
  }

  @override
  Widget build(BuildContext context) {
    final branchAsync = ref.watch(branchDetailProvider(widget.branchId));
    final appointment = ref.watch(bookingNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          'booking_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: branchAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
        data: (branchData) {
          if (appointment != null) {
            return _BookingSuccess(
              appointment: appointment,
              branchName: branchData.branch.name,
              branchAddress: branchData.branch.address,
              doctorName: _doctorNameOf(branchData.doctors, appointment.doctorId),
            );
          }
          return _BookingForm(
            clinicId: branchData.branch.clinicId,
            branchId: widget.branchId,
            doctors: branchData.doctors,
            preselectedDoctorId: widget.doctorId,
            departmentId: _departmentId,
            serviceId: _serviceId,
            doctorId: _doctorId,
            date: _date,
            slot: _slot,
            onDepartmentChanged: (id) => setState(() {
              _departmentId = id;
              _resetBelowDepartment();
            }),
            onServiceChanged: (id) => setState(() {
              _serviceId = id;
              _resetBelowService();
            }),
            onDoctorChanged: (id) => setState(() {
              _doctorId = id;
              _slot = null;
            }),
            onDateChanged: (date) => setState(() {
              _date = date;
              _slot = null;
            }),
            onSlotChanged: (slot) => setState(() => _slot = slot),
          );
        },
      ),
    );
  }

  String? _doctorNameOf(List<DoctorSummary> doctors, String doctorId) {
    for (final d in doctors) {
      if (d.id == doctorId) return d.name;
    }
    return null;
  }
}

class _BookingForm extends ConsumerWidget {
  const _BookingForm({
    required this.clinicId,
    required this.branchId,
    required this.doctors,
    required this.preselectedDoctorId,
    required this.departmentId,
    required this.serviceId,
    required this.doctorId,
    required this.date,
    required this.slot,
    required this.onDepartmentChanged,
    required this.onServiceChanged,
    required this.onDoctorChanged,
    required this.onDateChanged,
    required this.onSlotChanged,
  });

  final String clinicId;
  final String branchId;
  final List<DoctorSummary> doctors;
  final String? preselectedDoctorId;
  final String? departmentId;
  final String? serviceId;
  final String? doctorId;
  final DateTime date;
  final SlotModel? slot;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onServiceChanged;
  final ValueChanged<String?> onDoctorChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<SlotModel?> onSlotChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsProvider((clinicId: clinicId, branchId: branchId)));
    final servicesAsync = ref.watch(servicesProvider((clinicId: clinicId, branchId: branchId)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepLabel(number: 1, label: 'booking_step_department'.tr()),
          const SizedBox(height: 10),
          departmentsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, st) => Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext)),
            data: (departments) => _DepartmentPicker(
              departments: departments,
              selected: departmentId,
              onSelected: onDepartmentChanged,
            ),
          ),
          if (departmentId != null) ...[
            const SizedBox(height: 24),
            _StepLabel(number: 2, label: 'booking_step_service'.tr()),
            const SizedBox(height: 10),
            servicesAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, st) => Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext)),
              data: (services) {
                final filtered = services.where((s) => s.departmentId == departmentId).toList();
                return _ServicePicker(services: filtered, selected: serviceId, onSelected: onServiceChanged);
              },
            ),
          ],
          if (serviceId != null && preselectedDoctorId == null) ...[
            const SizedBox(height: 24),
            _StepLabel(number: 3, label: 'booking_step_doctor'.tr()),
            const SizedBox(height: 10),
            _DoctorPicker(
              doctors: doctors.where((d) => d.departmentIds.isEmpty || d.departmentIds.contains(departmentId)).toList(),
              selected: doctorId,
              onSelected: onDoctorChanged,
            ),
          ],
          if (serviceId != null && doctorId != null) ...[
            const SizedBox(height: 24),
            _StepLabel(number: preselectedDoctorId == null ? 4 : 3, label: 'booking_step_date'.tr()),
            const SizedBox(height: 10),
            DateStripPicker(selected: date, onSelected: onDateChanged),
            const SizedBox(height: 20),
            SlotChipPicker(
              doctorId: doctorId!,
              branchId: branchId,
              serviceId: serviceId!,
              date: date,
              selected: slot,
              onSelected: onSlotChanged,
            ),
          ],
          if (slot != null) ...[
            const SizedBox(height: 28),
            _ConfirmSection(
              clinicId: clinicId,
              branchId: branchId,
              doctorId: doctorId!,
              serviceId: serviceId!,
              date: date,
              slot: slot!,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: context.appPrimary, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: TextStyle(color: context.isDark ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DepartmentPicker extends StatelessWidget {
  const _DepartmentPicker({required this.departments, required this.selected, required this.onSelected});

  final List<DepartmentModel> departments;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) {
      return Text('booking_no_departments'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: departments
          .map((d) => BookingChip(label: d.name, isSelected: selected == d.id, onTap: () => onSelected(d.id)))
          .toList(),
    );
  }
}

class _ServicePicker extends StatelessWidget {
  const _ServicePicker({required this.services, required this.selected, required this.onSelected});

  final List<ServiceModel> services;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Text('booking_no_services'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13));
    }
    return Column(
      children: services
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                onTap: () => onSelected(s.id),
                child: CliniqnovvaCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  showBorder: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(
                              'booking_service_meta'.tr(
                                namedArgs: {
                                  'minutes': '${s.defaultDurationMins}',
                                  'price': NumberFormat.decimalPattern().format(s.defaultPriceRwf),
                                },
                              ),
                              style: TextStyle(color: context.appSubtext, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (selected == s.id) AppIcon(AppIcons.check, size: 20, color: context.appPrimary),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DoctorPicker extends StatelessWidget {
  const _DoctorPicker({required this.doctors, required this.selected, required this.onSelected});

  final List<DoctorSummary> doctors;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) {
      return Text('booking_no_doctors_for_department'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: doctors
          .map(
            (d) => BookingChip(
              label: d.name ?? '',
              subtitle: d.specialty,
              isSelected: selected == d.id,
              onTap: () => onSelected(d.id),
            ),
          )
          .toList(),
    );
  }
}

class _ConfirmSection extends ConsumerStatefulWidget {
  const _ConfirmSection({
    required this.clinicId,
    required this.branchId,
    required this.doctorId,
    required this.serviceId,
    required this.date,
    required this.slot,
  });

  final String clinicId;
  final String branchId;
  final String doctorId;
  final String serviceId;
  final DateTime date;
  final SlotModel slot;

  @override
  ConsumerState<_ConfirmSection> createState() => _ConfirmSectionState();
}

class _ConfirmSectionState extends ConsumerState<_ConfirmSection> {
  String? _error;

  bool get _isToday {
    final now = DateTime.now();
    return now.year == widget.date.year && now.month == widget.date.month && now.day == widget.date.day;
  }

  Future<void> _confirm() async {
    setState(() => _error = null);
    try {
      await ref.read(bookingNotifierProvider.notifier).submit(
            clinicId: widget.clinicId,
            branchId: widget.branchId,
            doctorId: widget.doctorId,
            serviceId: widget.serviceId,
            date: DateFormat('yyyy-MM-dd').format(widget.date),
            startTime: widget.slot.startTime,
            endTime: widget.slot.endTime,
          );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(bookingNotifierProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isToday)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('booking_same_day_note'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 12)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
          ),
        CliniqnovvaButton(label: 'action_confirm_booking'.tr(), isLoading: isLoading, onPressed: _confirm),
      ],
    );
  }
}

class _BookingSuccess extends StatelessWidget {
  const _BookingSuccess({
    required this.appointment,
    required this.branchName,
    required this.branchAddress,
    required this.doctorName,
  });

  final AppointmentModel appointment;
  final String branchName;
  final String? branchAddress;
  final String? doctorName;

  void _addToCalendar() {
    final date = DateFormat('yyyy-MM-dd').parse(appointment.date);
    final startParts = appointment.startTime.split(':').map(int.parse).toList();
    final endParts = appointment.endTime.split(':').map(int.parse).toList();
    final start = DateTime(date.year, date.month, date.day, startParts[0], startParts[1]);
    final end = DateTime(date.year, date.month, date.day, endParts[0], endParts[1]);

    Add2Calendar.addEvent2Cal(
      Event(
        title: doctorName != null ? 'Appointment with $doctorName' : '${AppConstants.appName} appointment',
        description: branchName,
        location: branchAddress ?? branchName,
        startDate: start,
        endDate: end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apptDate = DateFormat('yyyy-MM-dd').parse(appointment.date);
    final now = DateTime.now();
    final isToday = now.year == apptDate.year && now.month == apptDate.month && now.day == apptDate.day;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                AppIcon(AppIcons.check, size: 56, color: context.appPrimary),
                const SizedBox(height: 12),
                Text(
                  'booking_confirmed_title'.tr(),
                  style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'booking_detail_clinic'.tr(), value: branchName),
                if (doctorName != null) _DetailRow(label: 'booking_detail_doctor'.tr(), value: doctorName!),
                _DetailRow(
                  label: 'booking_detail_when'.tr(),
                  value: '${DateFormat.yMMMd().format(apptDate)}, ${appointment.startTime}',
                ),
              ],
            ),
          ),
          if (isToday) ...[
            const SizedBox(height: 16),
            Text('booking_same_day_note'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          CliniqnovvaButton(label: 'action_add_to_calendar'.tr(), onPressed: _addToCalendar),
          const SizedBox(height: 12),
          CliniqnovvaButton.text(
            label: 'action_view_booking'.tr(),
            isFullWidth: true,
            onPressed: () => context.go('/my-bookings/${appointment.id}'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: context.appSubtext, fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
