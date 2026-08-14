import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/searchable_dropdown.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../../clinics/providers/branches_provider.dart';
import '../models/staff_model.dart';
import '../providers/staff_provider.dart';

const _days = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];
const _dayLabels = {
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',
};
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

/// Part 8 Task 2 — /doctor-schedule. A Doctor sees/edits only their own
/// (view-only per spec 6.5 — no write role granted to Doctor); Branch
/// Admin/Receptionist/Clinic Admin can edit any doctor's schedule in
/// the branch (picked via a dropdown, or a branch selector first for an
/// Clinic Admin with several branches).
class DoctorScheduleScreen extends ConsumerWidget {
  const DoctorScheduleScreen({super.key});

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
          final isDoctor = role == AppConstants.roleDoctor;
          final isBranchScoped =
              isDoctor ||
              role == AppConstants.roleBranchAdmin ||
              role == AppConstants.roleReceptionist;
          final ownBranchId = data?['branchId'] as String?;

          return _ScheduleBody(
            isDoctor: isDoctor,
            canEdit: !isDoctor,
            ownDoctorId: isDoctor ? FirebaseService.currentUserId : null,
            branchId: isBranchScoped ? ownBranchId : null,
            showBranchSelector: !isBranchScoped,
          );
        },
      ),
    );
  }
}

class _ScheduleBody extends ConsumerStatefulWidget {
  const _ScheduleBody({
    required this.isDoctor,
    required this.canEdit,
    required this.ownDoctorId,
    required this.branchId,
    required this.showBranchSelector,
  });

  final bool isDoctor;
  final bool canEdit;
  final String? ownDoctorId;
  final String? branchId;
  final bool showBranchSelector;

  @override
  ConsumerState<_ScheduleBody> createState() => _ScheduleBodyState();
}

class _ScheduleBodyState extends ConsumerState<_ScheduleBody> {
  String? _selectedDoctorId;

  @override
  Widget build(BuildContext context) {
    final effectiveBranchId =
        widget.branchId ?? ref.watch(activeBranchIdProvider);

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
                  'Doctor Schedule',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              const TopBarActions(),
            ],
          ),
          const SizedBox(height: 24),
          if (effectiveBranchId == null)
            Expanded(child: const NoBranchSelectedState())
          else
            Expanded(
              child: SingleChildScrollView(
                child: widget.isDoctor
                    ? _DoctorScheduleContent(
                        key: ValueKey(widget.ownDoctorId),
                        doctorId: widget.ownDoctorId!,
                        branchId: effectiveBranchId,
                        canEdit: false,
                      )
                    : _DoctorPicker(
                        branchId: effectiveBranchId,
                        selectedDoctorId: _selectedDoctorId,
                        onChanged: (id) =>
                            setState(() => _selectedDoctorId = id),
                        builder: (doctorId) => _DoctorScheduleContent(
                          key: ValueKey(doctorId),
                          doctorId: doctorId,
                          branchId: effectiveBranchId,
                          canEdit: widget.canEdit,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Doctor dropdown fed by the branch's staff list, auto-selecting the first
/// doctor. Hands the resolved id to [builder] — a null doctorId (no doctors
/// in the branch yet) renders a plain message instead.
class _DoctorPicker extends ConsumerWidget {
  const _DoctorPicker({
    required this.branchId,
    required this.selectedDoctorId,
    required this.onChanged,
    required this.builder,
  });

  final String branchId;
  final String? selectedDoctorId;
  final ValueChanged<String?> onChanged;
  final Widget Function(String doctorId) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider(branchId));

    return staffAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (staff) {
        final doctors = staff
            .where((s) => s.role == AppConstants.roleDoctor)
            .toList();
        if (doctors.isEmpty) {
          return Text(
            'No doctors in this branch yet.',
            style: TextStyle(color: context.appSubtext),
          );
        }
        final currentId = doctors.any((d) => d.id == selectedDoctorId)
            ? selectedDoctorId
            : doctors.first.id;
        if (currentId != selectedDoctorId) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onChanged(currentId),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: SearchableDropdown(
                value: currentId,
                hint: 'Select doctor',
                items: doctors.map((d) => d.id).toList(),
                itemLabels: {for (final d in doctors) d.id: d.name},
                onChanged: onChanged,
              ),
            ),
            const SizedBox(height: 24),
            if (currentId != null) builder(currentId),
          ],
        );
      },
    );
  }
}

class _DoctorScheduleContent extends StatelessWidget {
  const _DoctorScheduleContent({
    super.key,
    required this.doctorId,
    required this.branchId,
    required this.canEdit,
  });

  final String doctorId;
  final String branchId;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeeklyScheduleSection(doctorId: doctorId, canEdit: canEdit),
        const SizedBox(height: 32),
        _BlockedSlotsSection(doctorId: doctorId, canEdit: canEdit),
        const SizedBox(height: 32),
        _UmugandaSection(branchId: branchId),
      ],
    );
  }
}

/// A locally-editable schedule entry — nulls until the user fills every
/// field, matching [DoctorScheduleEntry] once complete.
class _EditableEntry {
  _EditableEntry({this.day = 'monday', this.start, this.end, this.duration});
  String day;
  TimeOfDay? start;
  TimeOfDay? end;
  int? duration;
}

class _WeeklyScheduleSection extends ConsumerStatefulWidget {
  const _WeeklyScheduleSection({required this.doctorId, required this.canEdit});

  final String doctorId;
  final bool canEdit;

  @override
  ConsumerState<_WeeklyScheduleSection> createState() =>
      _WeeklyScheduleSectionState();
}

class _WeeklyScheduleSectionState
    extends ConsumerState<_WeeklyScheduleSection> {
  List<_EditableEntry>? _entries;
  TextEditingController? _breakMinutesController;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _breakMinutesController?.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String hhmm) {
    if (!hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(
    TimeOfDay? current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    final entries = _entries!;
    for (final e in entries) {
      if (e.start == null || e.end == null || e.duration == null) {
        setState(
          () =>
              _error = 'Fill in every slot\'s time and duration, or remove it.',
        );
        return;
      }
    }

    final breakMinutes = int.tryParse(_breakMinutesController!.text.trim());
    if (breakMinutes == null || breakMinutes < 0) {
      setState(
        () => _error = 'Break minutes must be a whole number, 0 or more.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(staffNotifierProvider.notifier)
          .setSchedule(
            widget.doctorId,
            entries
                .map(
                  (e) => DoctorScheduleEntry(
                    day: e.day,
                    startTime: _formatTime(e.start!),
                    endTime: _formatTime(e.end!),
                    slotDurationMins: e.duration!,
                  ),
                )
                .toList(),
            breakMinutes,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Schedule saved.')));
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
    final detailAsync = ref.watch(staffDetailProvider(widget.doctorId));

    return detailAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (doctor) {
        // Populate the editable list once per doctor (this widget is keyed
        // by doctorId at the call site, so a doctor switch remounts fresh).
        _entries ??= doctor.schedule
            .map(
              (e) => _EditableEntry(
                day: e.day,
                start: _parseTime(e.startTime),
                end: _parseTime(e.endTime),
                duration: e.slotDurationMins,
              ),
            )
            .toList();
        final entries = _entries!;
        _breakMinutesController ??= TextEditingController(
          text: '${doctor.breakMinutes}',
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: context.cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Weekly schedule',
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.canEdit)
                    CliniqnovvaButton.text(
                      label: '+ Add slot',
                      color: context.appText,
                      onPressed: () =>
                          setState(() => entries.add(_EditableEntry())),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 260,
                child: IgnorePointer(
                  ignoring: !widget.canEdit,
                  child: CliniqnovvaTextField(
                    label: 'Break between appointments (minutes)',
                    controller: _breakMinutesController,
                    hint: 'e.g. 10',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (entries.isEmpty)
                Text(
                  'No recurring availability set.',
                  style: TextStyle(color: context.appSubtext),
                )
              else
                ...entries.asMap().entries.map((mapEntry) {
                  final i = mapEntry.key;
                  final entry = mapEntry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 2,
                          child: IgnorePointer(
                            ignoring: !widget.canEdit,
                            child: AppSelect(
                              value: entry.day,
                              options: [
                                for (final d in _days)
                                  AppSelectOption(value: d, label: _dayLabels[d]!),
                              ],
                              onChanged: (value) => setState(
                                () => entry.day = value ?? entry.day,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _MiniTimeButton(
                            time: entry.start,
                            enabled: widget.canEdit,
                            onTap: () => _pickTime(
                              entry.start,
                              (t) => setState(() => entry.start = t),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _MiniTimeButton(
                            time: entry.end,
                            enabled: widget.canEdit,
                            onTap: () => _pickTime(
                              entry.end,
                              (t) => setState(() => entry.end = t),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: IgnorePointer(
                            ignoring: !widget.canEdit,
                            child: TextFormField(
                              initialValue: entry.duration?.toString(),
                              enabled: widget.canEdit,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: context.appText,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'mins',
                                filled: true,
                                fillColor: context.appCard,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.inputRadius,
                                  ),
                                  borderSide: BorderSide(
                                    color: context.appBorder,
                                  ),
                                ),
                              ),
                              onChanged: (value) =>
                                  entry.duration = int.tryParse(value.trim()),
                            ),
                          ),
                        ),
                        if (widget.canEdit) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: AppIcon(
                              AppIcons.trash,
                              size: 16,
                              color: context.appSubtext,
                            ),
                            onPressed: () =>
                                setState(() => entries.removeAt(i)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
              if (widget.canEdit) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  child: CliniqnovvaButton(
                    label: 'Save schedule',
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MiniTimeButton extends StatelessWidget {
  const _MiniTimeButton({
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final TimeOfDay? time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
        ),
        child: Text(
          time == null
              ? '--:--'
              : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: time == null ? context.appSubtext : context.appText,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _BlockedSlotsSection extends ConsumerStatefulWidget {
  const _BlockedSlotsSection({required this.doctorId, required this.canEdit});

  final String doctorId;
  final bool canEdit;

  @override
  ConsumerState<_BlockedSlotsSection> createState() =>
      _BlockedSlotsSectionState();
}

class _BlockedSlotsSectionState extends ConsumerState<_BlockedSlotsSection> {
  final _reasonController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _saving = false;
  String? _error;
  List<ConflictingAppointment>? _lastConflicts;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(
    TimeOfDay? current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _block() async {
    if (_date == null || _start == null || _end == null) {
      setState(() => _error = 'Set a date, start time, and end time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _lastConflicts = null;
    });

    String two(int n) => n.toString().padLeft(2, '0');
    final dateStr = '${_date!.year}-${two(_date!.month)}-${two(_date!.day)}';
    final startStr = '${two(_start!.hour)}:${two(_start!.minute)}';
    final endStr = '${two(_end!.hour)}:${two(_end!.minute)}';

    try {
      final result = await ref
          .read(staffNotifierProvider.notifier)
          .addBlockedSlot(
            widget.doctorId,
            date: dateStr,
            startTime: startStr,
            endTime: endStr,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _date = null;
        _start = null;
        _end = null;
        _reasonController.clear();
        _lastConflicts = result.conflictingAppointments;
      });
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
    final detailAsync = ref.watch(staffDetailProvider(widget.doctorId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Block a date/time',
            style: TextStyle(
              color: context.appText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.canEdit) ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.inputRadius),
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
                        _date == null ? 'Pick date' : _formatDate(_date!),
                        style: TextStyle(
                          color: _date == null
                              ? context.appSubtext
                              : context.appText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniTimeButton(
                    time: _start,
                    enabled: true,
                    onTap: () =>
                        _pickTime(_start, (t) => setState(() => _start = t)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniTimeButton(
                    time: _end,
                    enabled: true,
                    onTap: () =>
                        _pickTime(_end, (t) => setState(() => _end = t)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CliniqnovvaTextField(
              label: 'Reason',
              controller: _reasonController,
              hint: 'e.g. Leave, emergency',
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
                  style: const TextStyle(
                    color: AppColors.pillRedText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (_lastConflicts != null && _lastConflicts!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pillAmberBg,
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppIcon(
                          AppIcons.warning,
                          size: 16,
                          color: AppColors.pillAmberText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Blocked — but this overlaps ${_lastConflicts!.length} existing appointment${_lastConflicts!.length == 1 ? '' : 's'}. Review them:',
                            style: const TextStyle(
                              color: AppColors.pillAmberText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final conflict in _lastConflicts!)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${conflict.startTime ?? '?'}–${conflict.endTime ?? '?'} · appointment ${conflict.id}',
                          style: const TextStyle(
                            color: AppColors.pillAmberText,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: CliniqnovvaButton(
                label: 'Block',
                isLoading: _saving,
                onPressed: _saving ? null : _block,
              ),
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: context.appBorder),
            const SizedBox(height: 16),
          ],
          Text(
            'Blocked dates',
            style: TextStyle(
              color: context.appText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          detailAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) =>
                Text('$e', style: TextStyle(color: context.appSubtext)),
            data: (doctor) => doctor.blockedSlots.isEmpty
                ? Text(
                    'No blocked dates.',
                    style: TextStyle(color: context.appSubtext, fontSize: 13),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: doctor.blockedSlots
                        .map(
                          (slot) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${slot.date} · ${slot.startTime}–${slot.endTime}'
                              '${slot.reason != null ? ' — ${slot.reason}' : ''}',
                              style: TextStyle(
                                color: context.appText,
                                fontSize: 13,
                              ),
                            ),
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

class _UmugandaSection extends ConsumerWidget {
  const _UmugandaSection({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchDetailProvider(branchId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Umuganda Saturdays',
            style: TextStyle(
              color: context.appText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last Saturday of each month — community work morning.',
            style: TextStyle(color: context.appSubtext, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          branchAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) =>
                Text('$e', style: TextStyle(color: context.appSubtext)),
            data: (branch) => Text(
              branch.umugandaSaturdayHours != null
                  ? branch.umugandaSaturdayHours!.label
                  : 'Closed until midday (default — no branch override set)',
              style: TextStyle(
                color: context.appText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
