import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../organizations/models/organization.dart';
import '../../organizations/providers/organizations_provider.dart';

/// Part 4 Task 2 — clicking a billing row opens this: past payments plus a
/// "Record Payment" action. Same 480px slide-out pattern as Add Organization
/// (see DESIGN_LANGUAGE.md's "Slide-out panel" section).
Future<void> showPaymentHistoryPanel(BuildContext context, Organization organization) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Payment history',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: _PaymentHistoryPanel(organization: organization),
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
  const _PaymentHistoryPanel({required this.organization});

  final Organization organization;

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController(text: organization.subscriptionAmountRwf.toString());
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
                CliniqnovvaTextField(label: 'Note', controller: noteController, hint: 'Optional'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;

    await ref
        .read(organizationsNotifierProvider.notifier)
        .recordPayment(
          organization.id,
          amountRwf: amount,
          date: date,
          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(paymentHistoryProvider(organization.id));

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
                        organization.name,
                        style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(icon: const AppIcon(AppIcons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                Text('Payment history', style: TextStyle(color: context.appSubtext, fontSize: 13)),
                const SizedBox(height: 16),
                CliniqnovvaButton(
                  label: '+ Record Payment',
                  isFullWidth: false,
                  onPressed: () => _recordPayment(context, ref),
                ),
                const SizedBox(height: 16),
                const CliniqnovvaTableHeader(columns: ['Date', 'Amount', 'Recorded by']),
                Expanded(
                  child: historyAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Failed to load: $err', style: TextStyle(color: context.appSubtext))),
                    data: (payments) {
                      if (payments.isEmpty) {
                        return Center(
                          child: Text('No payments recorded yet.', style: TextStyle(color: context.appSubtext)),
                        );
                      }
                      final sorted = [...payments]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
                      return ListView(
                        children: [
                          for (final payment in sorted)
                            CliniqnovvaTableRow(
                              cells: [
                                Text(_formatDate(payment.date)),
                                Text(formatRwf(payment.amountRwf)),
                                Text(payment.recordedBy ?? '—', overflow: TextOverflow.ellipsis),
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
