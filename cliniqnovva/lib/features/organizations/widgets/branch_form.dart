import 'package:flutter/material.dart';

import '../../../core/constants/rwanda_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../models/branch_model.dart';

/// The one branch form used everywhere a branch is created or edited —
/// onboarding Step 1 renders it inline, the Add/Edit Branch panel renders it
/// in a modal (Part 6 Task 4: "reusable component").
///
/// Access the state through a `GlobalKey<BranchFormState>`: call
/// [BranchFormState.validate] (returns an error string or null), then
/// [BranchFormState.buildBody] for the API request body.
class BranchForm extends StatefulWidget {
  const BranchForm({super.key, this.initial, this.hoursOnly = false});

  /// Pre-fills every field when editing; null for a blank create form.
  final BranchModel? initial;

  /// Branch Admin mode (Part 6 Task 3): only the working-hours fields are
  /// shown/editable — everything else about their branch is read-only.
  final bool hoursOnly;

  @override
  State<BranchForm> createState() => BranchFormState();
}

class BranchFormState extends State<BranchForm> {
  final _nameController = TextEditingController();
  final _sectorController = TextEditingController();
  final _cellController = TextEditingController();
  final _villageController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _province;
  String? _district;
  bool _open24Hours = false;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  bool _umugandaOverride = false;
  TimeOfDay? _umugandaOpenTime;
  TimeOfDay? _umugandaCloseTime;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _nameController.text = initial.name;
      _sectorController.text = initial.location?.sector ?? '';
      _cellController.text = initial.location?.cell ?? '';
      _villageController.text = initial.location?.village ?? '';
      _phoneController.text = initial.phone ?? '';
      _province = initial.location?.province;
      _district = initial.location?.district;
      _open24Hours = initial.workingHours?.is24Hours ?? false;
      _openTime = _parseTime(initial.workingHours?.start);
      _closeTime = _parseTime(initial.workingHours?.end);
      _umugandaOverride = initial.umugandaSaturdayHours != null;
      _umugandaOpenTime = _parseTime(initial.umugandaSaturdayHours?.start);
      _umugandaCloseTime = _parseTime(initial.umugandaSaturdayHours?.end);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectorController.dispose();
    _cellController.dispose();
    _villageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Closing time is at/past midnight relative to opening — the branch
  /// closes on the following day (e.g. 20:00 → 04:00).
  bool get _isOvernight =>
      _openTime != null &&
      _closeTime != null &&
      _minutes(_closeTime!) < _minutes(_openTime!);

  /// Part 6 Task 4 validation (2026-07-23: supports 24-hour and overnight
  /// clinics). A closing time earlier than the opening time is VALID — it
  /// means the branch closes the next day. Only start == end is rejected;
  /// that's what the "Open 24 hours" toggle is for. Returns a user-facing
  /// message, or null when the form is valid.
  String? validate() {
    if (!widget.hoursOnly) {
      if (_nameController.text.trim().isEmpty) return 'Branch name is required.';
      if (_province == null) return 'Province is required.';
      if (_district == null) return 'District is required.';
    }
    if (!_open24Hours) {
      if (_openTime == null || _closeTime == null) {
        return 'Working hours (opening and closing time) are required — or turn on "Open 24 hours".';
      }
      if (_minutes(_openTime!) == _minutes(_closeTime!)) {
        return 'Opening and closing time can\'t be the same — turn on "Open 24 hours" instead.';
      }
    }
    if (_umugandaOverride) {
      if (_umugandaOpenTime == null || _umugandaCloseTime == null) {
        return 'Set the Umuganda Saturday opening and closing time, or turn the override off.';
      }
      if (_minutes(_umugandaOpenTime!) == _minutes(_umugandaCloseTime!)) {
        return 'Umuganda Saturday: opening and closing time can\'t be the same.';
      }
    }
    return null;
  }

  /// The API request body. In [BranchForm.hoursOnly] mode only the hours
  /// fields are included — the backend rejects anything more from a Branch
  /// Admin anyway.
  Map<String, dynamic> buildBody() {
    final hours = {
      'workingHours': _open24Hours
          ? {'is24Hours': true}
          : {
              'start': _formatTime(_openTime!),
              'end': _formatTime(_closeTime!),
            },
      'umugandaSaturdayHours': _umugandaOverride
          ? {
              'start': _formatTime(_umugandaOpenTime!),
              'end': _formatTime(_umugandaCloseTime!),
            }
          : null,
    };
    if (widget.hoursOnly) return hours;

    return {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'location': {
        'province': _province,
        'district': _district,
        'sector': _emptyToNull(_sectorController.text),
        'cell': _emptyToNull(_cellController.text),
        'village': _emptyToNull(_villageController.text),
      },
      ...hours,
    };
  }

  static String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.hoursOnly) ...[
          CliniqnovvaTextField(
            label: 'Branch name',
            controller: _nameController,
            hint: 'e.g. Kimironko Branch',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledDropdown(
                  label: 'Province',
                  value: _province,
                  hint: 'Select province',
                  items: RwandaLocations.provinces,
                  onChanged: (value) => setState(() {
                    _province = value;
                    // A district belongs to one province — changing province
                    // invalidates the old district selection.
                    _district = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledDropdown(
                  label: 'District',
                  value: _district,
                  hint: _province == null
                      ? 'Select province first'
                      : 'Select district',
                  items: RwandaLocations.districtsOf(_province),
                  onChanged: (value) => setState(() => _district = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Sector (optional)',
                  controller: _sectorController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Cell (optional)',
                  controller: _cellController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Village (optional)',
                  controller: _villageController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Phone',
                  controller: _phoneController,
                  hint: '+250 7XX XXX XXX',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Working hours',
          style: TextStyle(
            color: context.appText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 36,
              height: 24,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: _open24Hours,
                  activeTrackColor: context.appPrimary,
                  onChanged: (value) => setState(() => _open24Hours = value),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Open 24 hours',
                style: TextStyle(color: context.appText, fontSize: 13.5),
              ),
            ),
          ],
        ),
        if (!_open24Hours) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Opens',
                  time: _openTime,
                  onTap: () => _pickTime(
                    _openTime,
                    (t) => setState(() => _openTime = t),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeButton(
                  label: 'Closes',
                  time: _closeTime,
                  onTap: () => _pickTime(
                    _closeTime,
                    (t) => setState(() => _closeTime = t),
                  ),
                ),
              ),
            ],
          ),
          if (_isOvernight) ...[
            const SizedBox(height: 6),
            Text(
              'Closes after midnight — the next day.',
              style: TextStyle(color: context.appSubtext, fontSize: 12.5),
            ),
          ],
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 36,
              height: 24,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: _umugandaOverride,
                  activeTrackColor: context.appPrimary,
                  onChanged: (value) =>
                      setState(() => _umugandaOverride = value),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Different hours on Umuganda Saturdays',
                style: TextStyle(color: context.appText, fontSize: 13.5),
              ),
            ),
          ],
        ),
        if (_umugandaOverride) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Opens (Umuganda)',
                  time: _umugandaOpenTime,
                  onTap: () => _pickTime(
                    _umugandaOpenTime,
                    (t) => setState(() => _umugandaOpenTime = t),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeButton(
                  label: 'Closes (Umuganda)',
                  time: _umugandaCloseTime,
                  onTap: () => _pickTime(
                    _umugandaCloseTime,
                    (t) => setState(() => _umugandaCloseTime = t),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Label-above-field dropdown styled to match [CliniqnovvaTextField].
class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(color: context.appSubtext, fontSize: 14),
            overflow: TextOverflow.ellipsis,
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
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A tappable field-look button showing a picked time (or a placeholder),
/// opening the Material time picker.
class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.appSubtext, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: context.appBorder),
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            ),
            child: Text(
              time == null
                  ? 'Pick time'
                  : BranchFormState._formatTime(time!),
              style: TextStyle(
                color: time == null ? context.appSubtext : context.appText,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
