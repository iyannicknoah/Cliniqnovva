import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';

/// Part 13 Task 3 — manual stock correction. Always signed (a restock is
/// +N, a breakage/write-off is -N) and always requires a reason, so
/// "every change logged with reason + staff ID" holds for manual
/// corrections just like it does for dispensing.
Future<void> showAdjustStockDialog(
  BuildContext context, {
  required InventoryItemModel item,
}) {
  return showDialog(
    context: context,
    builder: (context) => _AdjustStockDialog(item: item),
  );
}

class _AdjustStockDialog extends ConsumerStatefulWidget {
  const _AdjustStockDialog({required this.item});

  final InventoryItemModel item;

  @override
  ConsumerState<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<_AdjustStockDialog> {
  bool _isRestock = true;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a positive whole number.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'A reason is required for every stock adjustment.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await runWithFeedback(
        context,
        () => ref.read(inventoryNotifierProvider.notifier).adjust(
          widget.item.id,
          quantityChange: _isRestock ? amount : -amount,
          reason: reason,
        ),
        loadingMessage: 'Saving adjustment…',
        successMessage: 'Stock adjusted.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
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
    return Dialog(
      backgroundColor: context.appCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjust stock — ${widget.item.name}',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current: ${widget.item.quantity} ${widget.item.unit}',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DirectionChip(
                      label: 'Restock (+)',
                      selected: _isRestock,
                      onTap: () => setState(() => _isRestock = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DirectionChip(
                      label: 'Write off (−)',
                      selected: !_isRestock,
                      onTap: () => setState(() => _isRestock = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CliniqnovvaTextField(
                label: 'Quantity',
                controller: _amountController,
                hint: 'e.g. 20',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CliniqnovvaTextField(
                label: 'Reason',
                controller: _reasonController,
                hint: 'e.g. Delivery from supplier, expired write-off…',
              ),
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
                    style: const TextStyle(color: AppColors.pillRedText, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CliniqnovvaButton.text(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CliniqnovvaButton(
                      label: 'Save',
                      isLoading: _saving,
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.appSecondaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          border: Border.all(color: context.appBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.appText,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
