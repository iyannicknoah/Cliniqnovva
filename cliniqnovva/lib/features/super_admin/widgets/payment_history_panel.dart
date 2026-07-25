import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../clinics/models/clinic.dart';
import '../../clinics/providers/clinics_provider.dart';

const _billingStatuses = ['notPaid', 'pending', 'paid'];

String _billingStatusLabel(String status) => switch (status) {
  'paid' => 'Paid',
  'pending' => 'Pending',
  _ => 'Not Paid',
};

/// Part 4 Task 2 — clicking a billing row opens this: past payments plus a
/// "Record Payment" action. Same 480px slide-out pattern as Add Clinic
/// (see DESIGN_LANGUAGE.md's "Slide-out panel" section).
Future<void> showPaymentHistoryPanel(
  BuildContext context,
  Clinic clinic,
) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Payment history',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: _PaymentHistoryPanel(clinic: clinic),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return SlideTransition(position: offset, child: child);
    },
  );
}

String formatRwf(num amount) {
  final s = amount.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$buf RWF';
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _PaymentHistoryPanel extends ConsumerWidget {
  const _PaymentHistoryPanel({required this.clinic});

  final Clinic clinic;

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController(
      text: clinic.subscriptionAmountRwf.toString(),
    );
    final noteController = TextEditingController();
    DateTime date = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Record payment'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CliniqnovvaTextField(
                  label: 'Amount (RWF)',
                  controller: amountController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(_formatDate(date)),
                  ),
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Note',
                  controller: noteController,
                  hint: 'Optional',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;

    await runWithFeedback(
      context,
      () => ref
          .read(clinicsNotifierProvider.notifier)
          .recordPayment(
            clinic.id,
            amountRwf: amount,
            date: date,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          ),
      loadingMessage: 'Recording payment…',
      successMessage: 'Payment recorded.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(paymentHistoryProvider(clinic.id));
    final orgAsync = ref.watch(clinicDetailProvider(clinic.id));
    final currentOrg = orgAsync.valueOrNull ?? clinic;
    final canRecordPayment = currentOrg.billingStatus == 'paid';

    return Material(
      color: context.appCard,
      child: SafeArea(
        child: SizedBox(
          width: 480,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clinic.name,
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
                const SizedBox(height: 16),
                Text(
                  'Billing status',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final status in _billingStatuses) ...[
                      _BillingStatusChip(
                        label: _billingStatusLabel(status),
                        selected: currentOrg.billingStatus == status,
                        onTap: () => runWithFeedback(
                          context,
                          () => ref
                              .read(clinicsNotifierProvider.notifier)
                              .setBillingStatus(clinic.id, status),
                          loadingMessage: 'Updating billing status…',
                          successMessage:
                              'Billing status set to ${_billingStatusLabel(status)}.',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment history',
                  style: TextStyle(color: context.appSubtext, fontSize: 13),
                ),
                const SizedBox(height: 16),
                CliniqnovvaButton(
                  label: '+ Record Payment',
                  isFullWidth: false,
                  onPressed: canRecordPayment
                      ? () => _recordPayment(context, ref)
                      : null,
                ),
                if (!canRecordPayment) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Mark this clinic Paid before recording a payment.',
                    style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 16),
                const CliniqnovvaTableHeader(
                  columns: ['Date', 'Amount', 'Recorded by'],
                ),
                Expanded(
                  child: historyAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text(
                        'Failed to load: $err',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    ),
                    data: (payments) {
                      if (payments.isEmpty) {
                        return Center(
                          child: Text(
                            'No payments recorded yet.',
                            style: TextStyle(color: context.appSubtext),
                          ),
                        );
                      }
                      final sorted = [...payments]
                        ..sort(
                          (a, b) => (b.date ?? DateTime(0)).compareTo(
                            a.date ?? DateTime(0),
                          ),
                        );
                      return ListView(
                        children: [
                          for (final payment in sorted)
                            CliniqnovvaTableRow(
                              cells: [
                                Text(_formatDate(payment.date)),
                                Text(formatRwf(payment.amountRwf)),
                                Text(
                                  payment.recordedBy ?? '—',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable billing-status option (Not Paid / Pending / Paid) — filled
/// black/white when selected (system primary), border-only otherwise, same
/// inversion rule as `CliniqnovvaButton`.
class _BillingStatusChip extends StatelessWidget {
  const _BillingStatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.appPrimary : Colors.transparent;
    final fg = selected
        ? (context.isDark ? Colors.black : Colors.white)
        : context.appText;

    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? bg : context.appBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
