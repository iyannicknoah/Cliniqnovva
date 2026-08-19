import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../patients/models/medical_record_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';

/// One undispensed prescription, with enough context to dispense against it.
typedef _PendingPrescription = ({
  String medicalRecordId,
  int prescriptionIndex,
  Prescription prescription,
});

/// Part 13 Task 2 — the dispense flow: select prescription → matching stock
/// item → deduct. Three steps, each unlocked by the previous: pick a
/// patient, pick one of their undispensed prescriptions, pick the stock
/// item to deduct from.
class DispensePanel extends ConsumerStatefulWidget {
  const DispensePanel({super.key, required this.branchId});

  final String branchId;

  @override
  ConsumerState<DispensePanel> createState() => _DispensePanelState();
}

class _DispensePanelState extends ConsumerState<DispensePanel> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _patientId;
  String? _patientName;

  _PendingPrescription? _pending;

  String? _itemId;
  final _quantityController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();
  bool _dispensing = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _selectPatient(String id, String name) {
    setState(() {
      _patientId = id;
      _patientName = name;
      _pending = null;
      _itemId = null;
      _error = null;
    });
  }

  void _changePatient() {
    setState(() {
      _patientId = null;
      _patientName = null;
      _pending = null;
      _itemId = null;
      _searchController.clear();
      _query = '';
    });
  }

  void _selectPrescription(_PendingPrescription p) {
    setState(() {
      _pending = p;
      _itemId = null;
      _quantityController.text = '1';
      _reasonController.clear();
      _error = null;
    });
  }

  Future<void> _dispense() async {
    final pending = _pending;
    final patientId = _patientId;
    final itemId = _itemId;
    if (pending == null || patientId == null || itemId == null) return;

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter a positive whole number for quantity.');
      return;
    }

    setState(() {
      _dispensing = true;
      _error = null;
    });

    try {
      await runWithFeedback(
        context,
        () => ref.read(inventoryNotifierProvider.notifier).dispense(
          itemId: itemId,
          quantity: quantity,
          patientId: patientId,
          medicalRecordId: pending.medicalRecordId,
          prescriptionIndex: pending.prescriptionIndex,
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        ),
        loadingMessage: 'Dispensing…',
        successMessage: 'Dispensed — stock updated.',
      );
      if (!mounted) return;
      ref.invalidate(patientDetailProvider(patientId));
      setState(() {
        _dispensing = false;
        _pending = null;
        _itemId = null;
      });
    } catch (e) {
      if (!mounted) return;
      final isInsufficientStock = e is ApiException && e.statusCode == 409;
      setState(() {
        _dispensing = false;
        _error = isInsufficientStock
            ? '$e (item flagged for reorder)'
            : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepCard(
            step: '1',
            title: 'Patient',
            child: _patientId == null
                ? _PatientSearch(
                    controller: _searchController,
                    query: _query,
                    branchId: widget.branchId,
                    onQueryChanged: (v) => setState(() => _query = v),
                    onSelected: _selectPatient,
                  )
                : Row(
                    children: [
                      AvatarWidget(firstName: _patientName ?? '', size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _patientName ?? '',
                          style: TextStyle(
                            color: context.appText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      CliniqnovvaButton.text(
                        label: 'Change',
                        onPressed: _changePatient,
                      ),
                    ],
                  ),
          ),
          if (_patientId != null) ...[
            const SizedBox(height: 20),
            _StepCard(
              step: '2',
              title: 'Prescription',
              child: _PrescriptionPicker(
                patientId: _patientId!,
                selected: _pending,
                onSelected: _selectPrescription,
              ),
            ),
          ],
          if (_pending != null) ...[
            const SizedBox(height: 20),
            _StepCard(
              step: '3',
              title: 'Dispense',
              child: _DispenseStep(
                branchId: widget.branchId,
                medicineName: _pending!.prescription.medicineName,
                itemId: _itemId,
                onItemSelected: (id) => setState(() => _itemId = id),
                quantityController: _quantityController,
                reasonController: _reasonController,
                error: _error,
                dispensing: _dispensing,
                onDispense: _itemId == null ? null : _dispense,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaCard(
      title: '$step. $title',
      child: child,
    );
  }
}

class _PatientSearch extends ConsumerWidget {
  const _PatientSearch({
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
  final void Function(String id, String name) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CliniqnovvaTextField(
          label: 'Search',
          controller: controller,
          hint: 'Name, phone, or National ID',
          onChanged: onQueryChanged,
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
                                onTap: () => onSelected(p.id, p.name),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      AvatarWidget(firstName: p.name, size: 28),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
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

class _PrescriptionPicker extends ConsumerWidget {
  const _PrescriptionPicker({
    required this.patientId,
    required this.selected,
    required this.onSelected,
  });

  final String patientId;
  final _PendingPrescription? selected;
  final ValueChanged<_PendingPrescription> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));

    return patientAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (patient) {
        final records = patient.medicalRecords ?? [];
        final pending = <_PendingPrescription>[];
        for (final record in records) {
          for (var i = 0; i < record.prescriptions.length; i++) {
            final p = record.prescriptions[i];
            if (!p.dispensed) {
              pending.add((
                medicalRecordId: record.id,
                prescriptionIndex: i,
                prescription: p,
              ));
            }
          }
        }

        if (pending.isEmpty) {
          return Text(
            'No undispensed prescriptions for this patient.',
            style: TextStyle(color: context.appSubtext),
          );
        }

        return Column(
          children: pending.map((p) {
            final isSelected =
                selected?.medicalRecordId == p.medicalRecordId &&
                selected?.prescriptionIndex == p.prescriptionIndex;
            return InkWell(
              onTap: () => onSelected(p),
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? context.appSecondaryBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                  border: Border.all(
                    color: isSelected ? context.appPrimary : context.appBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.prescription.medicineName,
                            style: TextStyle(
                              color: context.appText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (p.prescription.dosage != null ||
                              p.prescription.duration != null)
                            Text(
                              [
                                if (p.prescription.dosage != null)
                                  p.prescription.dosage!,
                                if (p.prescription.duration != null)
                                  p.prescription.duration!,
                              ].join(' — '),
                              style: TextStyle(
                                color: context.appSubtext,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: context.appPrimary, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DispenseStep extends ConsumerWidget {
  const _DispenseStep({
    required this.branchId,
    required this.medicineName,
    required this.itemId,
    required this.onItemSelected,
    required this.quantityController,
    required this.reasonController,
    required this.error,
    required this.dispensing,
    required this.onDispense,
  });

  final String branchId;
  final String medicineName;
  final String? itemId;
  final ValueChanged<String> onItemSelected;
  final TextEditingController quantityController;
  final TextEditingController reasonController;
  final String? error;
  final bool dispensing;
  final VoidCallback? onDispense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inventoryListProvider(branchId));

    return itemsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (items) {
        final dispensable = items
            .where((i) => i.isActive && !i.isExpired)
            .toList();
        final needle = medicineName.toLowerCase();
        final suggested = dispensable
            .where(
              (i) =>
                  i.name.toLowerCase().contains(needle) ||
                  needle.contains(i.name.toLowerCase()),
            )
            .toList();
        final others = dispensable
            .where((i) => !suggested.contains(i))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Matching stock for "$medicineName"',
              style: TextStyle(color: context.appSubtext, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            if (suggested.isEmpty)
              Text(
                'No matching item name in stock — pick from all items below.',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              )
            else
              ...suggested.map((i) => _ItemChoice(
                item: i,
                selected: itemId == i.id,
                onTap: () => onItemSelected(i.id),
              )),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Other items',
                style: TextStyle(color: context.appSubtext, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              ...others.map((i) => _ItemChoice(
                item: i,
                selected: itemId == i.id,
                onTap: () => onItemSelected(i.id),
              )),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CliniqnovvaTextField(
                    label: 'Quantity',
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CliniqnovvaTextField(
                    label: 'Reason (optional)',
                    controller: reasonController,
                    hint: 'Defaults to the prescription name',
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pillRedBg,
                  borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: AppColors.pillRedText, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            CliniqnovvaButton(
              label: 'Dispense',
              isLoading: dispensing,
              onPressed: dispensing ? null : onDispense,
            ),
          ],
        );
      },
    );
  }
}

class _ItemChoice extends StatelessWidget {
  const _ItemChoice({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final InventoryItemModel item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? context.appSecondaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          border: Border.all(
            color: selected ? context.appPrimary : context.appBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${item.quantity} ${item.unit} in stock',
              style: TextStyle(
                color: item.needsReorder ? AppColors.pillAmberText : context.appSubtext,
                fontSize: 12.5,
                fontWeight: item.needsReorder ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
