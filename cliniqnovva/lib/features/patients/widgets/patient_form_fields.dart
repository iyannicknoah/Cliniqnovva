import 'package:flutter/material.dart';

import '../../../core/constants/rwanda_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_select.dart';
import '../models/patient_model.dart';

/// Shared by the Register and Profile-edit forms (Part 9 Tasks 2-3) — same
/// pattern as [BranchForm]: a `GlobalKey<PatientAddressFormState>` exposes
/// [PatientAddressFormState.isValid]/[value] so the parent form validates
/// and reads it without owning the province/district cascade itself.
/// Province/district are required together if the address is used at all
/// (Part 9 Task 2: address as a whole is optional — phone is the only
/// required field — but its two headline parts aren't independently optional).
class PatientAddressForm extends StatefulWidget {
  const PatientAddressForm({super.key, this.initial});

  final PatientLocation? initial;

  @override
  State<PatientAddressForm> createState() => PatientAddressFormState();
}

class PatientAddressFormState extends State<PatientAddressForm> {
  final _sectorController = TextEditingController();
  final _cellController = TextEditingController();
  final _villageController = TextEditingController();
  String? _province;
  String? _district;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _province = initial.province;
      _district = initial.district;
      _sectorController.text = initial.sector ?? '';
      _cellController.text = initial.cell ?? '';
      _villageController.text = initial.village ?? '';
    }
  }

  @override
  void dispose() {
    _sectorController.dispose();
    _cellController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  /// True unless exactly one of province/district is set (an incomplete
  /// address) — both null (skip entirely) and both set are valid.
  bool get isValid => (_province == null) == (_district == null);

  static String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  PatientLocation? get value => _province == null
      ? null
      : PatientLocation(
          province: _province,
          district: _district,
          sector: _emptyToNull(_sectorController.text),
          cell: _emptyToNull(_cellController.text),
          village: _emptyToNull(_villageController.text),
        );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledDropdown(
                label: 'Province',
                value: _province,
                hint: 'Select province',
                items: RwandaLocations.provinces,
                onChanged: (value) => setState(() {
                  _province = value;
                  _district = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LabeledDropdown(
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
              child: _PlainField(label: 'Sector', controller: _sectorController),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlainField(label: 'Cell', controller: _cellController),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlainField(label: 'Village', controller: _villageController),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlainField extends StatelessWidget {
  const _PlainField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

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
        TextField(
          controller: controller,
          style: TextStyle(color: context.appText, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.appCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
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
        ),
      ],
    );
  }
}

/// Label-above dropdown styled like [CliniqnovvaTextField] — same shape
/// used by branch/service/staff forms, kept public here so Patients screens
/// can share it too.
class LabeledDropdown extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.itemLabels,
  });

  final String label;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  /// Optional item -> display text map (e.g. 'female' -> 'Female'). Falls
  /// back to the raw item value when absent or missing an entry.
  final Map<String, String>? itemLabels;

  @override
  Widget build(BuildContext context) {
    return AppSelect(
      label: label,
      value: items.contains(value) ? value : null,
      hint: hint,
      options: items
          .map((item) => AppSelectOption(value: item, label: itemLabels?[item] ?? item))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Tappable field-look button opening [showDatePicker] — same visual
/// pattern as [BranchForm]'s time buttons, for a date instead.
class PatientDateField extends StatelessWidget {
  const PatientDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

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
        InkWell(
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: context.appBorder),
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            ),
            child: Text(
              date == null
                  ? 'Pick a date'
                  : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: date == null ? context.appSubtext : context.appText,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GenderDropdown extends StatelessWidget {
  const GenderDropdown({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const options = ['female', 'male', 'other'];
  static const labels = {'female': 'Female', 'male': 'Male', 'other': 'Other'};

  @override
  Widget build(BuildContext context) {
    return LabeledDropdown(
      label: 'Gender',
      value: value,
      hint: 'Select',
      items: options,
      itemLabels: labels,
      onChanged: onChanged,
    );
  }
}
