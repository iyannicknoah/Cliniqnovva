import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/success_dialog.dart';
import '../../patients/widgets/patient_form_fields.dart';
import '../models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';

/// Part 13 Task 1 — "+ Add Item" panel. 2026-08-15, explicit user
/// instruction — switched from a right-edge slide-out to a centered modal
/// with rounded corners, matching the Register Patient/Add Branch/Invoice
/// Detail pattern elsewhere in the app. Create when [item] is null, edit
/// otherwise. Editing never touches quantity — that's Task 3's job (adjust
/// dialog), so it's always logged with a reason.
Future<void> showInventoryItemPanel(
  BuildContext context, {
  required String branchId,
  InventoryItemModel? item,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Item',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: _ItemPanel(branchId: branchId, item: item),
    ),
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

class _ItemPanel extends ConsumerStatefulWidget {
  const _ItemPanel({required this.branchId, this.item});

  final String branchId;
  final InventoryItemModel? item;

  @override
  ConsumerState<_ItemPanel> createState() => _ItemPanelState();
}

class _ItemPanelState extends ConsumerState<_ItemPanel> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  DateTime? _expiryDate;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameController.text = item.name;
      _unitController.text = item.unit;
      _categoryController.text = item.category ?? '';
      _reorderLevelController.text = item.reorderLevel.toString();
      _expiryDate = item.expiryDate != null
          ? DateTime.tryParse(item.expiryDate!)
          : null;
    } else {
      _reorderLevelController.text = '10';
      _quantityController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _reorderLevelController.dispose();
    super.dispose();
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final category = _categoryController.text.trim();
    final reorderLevel = int.tryParse(_reorderLevelController.text.trim());

    if (name.isEmpty) {
      setState(() => _error = 'Item name is required.');
      return;
    }
    if (unit.isEmpty) {
      setState(() => _error = 'Unit (e.g. tablet, bottle) is required.');
      return;
    }
    if (reorderLevel == null || reorderLevel < 0) {
      setState(() => _error = 'Reorder level must be a non-negative whole number.');
      return;
    }

    int? quantity;
    if (!_isEdit) {
      quantity = int.tryParse(_quantityController.text.trim());
      if (quantity == null || quantity < 0) {
        setState(() => _error = 'Starting quantity must be a non-negative whole number.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(inventoryNotifierProvider.notifier);
      await runWithFeedback(
        context,
        () => _isEdit
            ? notifier.updateItem(
                widget.item!.id,
                name: name,
                unit: unit,
                category: category.isEmpty ? null : category,
                reorderLevel: reorderLevel,
                expiryDate: _expiryDate != null ? _isoDate(_expiryDate!) : null,
              )
            : notifier.create(
                branchId: widget.branchId,
                name: name,
                unit: unit,
                category: category.isEmpty ? null : category,
                quantity: quantity!,
                reorderLevel: reorderLevel,
                expiryDate: _expiryDate != null ? _isoDate(_expiryDate!) : null,
              ),
        loadingMessage: _isEdit ? 'Saving item…' : 'Adding item…',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessDialog(
        context,
        message: _isEdit ? 'Item saved.' : 'Item added.',
      );
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
    return Material(
      color: context.appCard,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: context.appBorder),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Item' : 'Add Item',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CliniqnovvaTextField(
                          label: 'Item name',
                          controller: _nameController,
                          hint: 'e.g. Coartem',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CliniqnovvaTextField(
                                label: 'Unit',
                                controller: _unitController,
                                hint: 'e.g. tablet, bottle',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CliniqnovvaTextField(
                                label: 'Category (optional)',
                                controller: _categoryController,
                                hint: 'e.g. Antimalarial',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (!_isEdit)
                              Expanded(
                                child: CliniqnovvaTextField(
                                  label: 'Starting quantity',
                                  controller: _quantityController,
                                  hint: 'e.g. 100',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            if (!_isEdit) const SizedBox(width: 12),
                            Expanded(
                              child: CliniqnovvaTextField(
                                label: 'Reorder level',
                                controller: _reorderLevelController,
                                hint: 'e.g. 10',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        PatientDateField(
                          label: 'Expiry date (optional)',
                          date: _expiryDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiryDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _expiryDate = picked);
                            }
                          },
                        ),
                        if (_isEdit) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Current stock: ${widget.item!.quantity} ${widget.item!.unit}. '
                            'Use "Adjust stock" from the table to change it.',
                            style: TextStyle(
                              color: context.appSubtext,
                              fontSize: 12.5,
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
                              borderRadius: BorderRadius.circular(
                                AppTheme.inputRadius,
                              ),
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
                ),
                const SizedBox(height: 16),
                CliniqnovvaButton(
                  label: 'Save',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
