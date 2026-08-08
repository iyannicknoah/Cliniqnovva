import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/status_badge.dart';
import 'models/invoice_model.dart';
import 'providers/records_provider.dart';

/// Pushed on top of the shell — reached from Settings, not a bottom-nav
/// tab. Part 23 Task 2: every invoice across every clinic this patient has
/// been billed by, newest first.
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  BadgeType _badgeTypeFor(String status) {
    switch (status) {
      case 'paid':
        return BadgeType.success;
      case 'voided':
        return BadgeType.error;
      default:
        return BadgeType.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoicesProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          'settings_receipts'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (invoices) {
          if (invoices.isEmpty) {
            return Center(child: Text('receipts_empty'.tr(), style: TextStyle(color: context.appSubtext)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: invoices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _InvoiceCard(
              invoice: invoices[index],
              badgeType: _badgeTypeFor(invoices[index].status),
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.badgeType});

  final InvoiceModel invoice;
  final BadgeType badgeType;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/receipts/${invoice.id}'),
      child: CliniqnovvaCard(
        child: Row(
          children: [
            AppIcon(AppIcons.receipt, size: 22, color: context.appPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.clinicName ?? '…',
                    style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (invoice.createdAt != null)
                    Text(DateFormat.yMMMd().format(invoice.createdAt!), style: TextStyle(color: context.appSubtext, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'amount_rwf'.tr(namedArgs: {'amount': NumberFormat.decimalPattern().format(invoice.totalAmountRwf)}),
                  style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                StatusBadge(text: 'invoice_status_${invoice.status}'.tr(), type: badgeType),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
