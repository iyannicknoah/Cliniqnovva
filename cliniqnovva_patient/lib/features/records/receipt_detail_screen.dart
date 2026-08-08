import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/status_badge.dart';
import 'models/invoice_model.dart';
import 'providers/records_provider.dart';

/// Pushed on top of the shell. Part 23 Task 2's invoice breakdown + PDF
/// receipt — the PDF generation itself mirrors the web dashboard's
/// `invoice_detail_screen.dart#_generateReceiptPdf` layout and field set
/// exactly (same `pdf`/`printing` packages, same A5 single-page structure,
/// same plain-RWF-no-thousands-separator line-item formatting), not a
/// backend PDF endpoint — there isn't one, Part 12 built this client-side.
class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

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
          onPressed: () => context.canPop() ? context.pop() : context.go('/receipts'),
        ),
        title: Text(
          'receipt_detail_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (invoices) {
          InvoiceModel? invoice;
          for (final inv in invoices) {
            if (inv.id == invoiceId) {
              invoice = inv;
              break;
            }
          }
          if (invoice == null) {
            return Center(child: Text('receipt_not_found'.tr(), style: TextStyle(color: context.appSubtext)));
          }
          return _ReceiptDetailBody(invoice: invoice, badgeType: _badgeTypeFor(invoice.status));
        },
      ),
    );
  }
}

class _ReceiptDetailBody extends StatefulWidget {
  const _ReceiptDetailBody({required this.invoice, required this.badgeType});

  final InvoiceModel invoice;
  final BadgeType badgeType;

  @override
  State<_ReceiptDetailBody> createState() => _ReceiptDetailBodyState();
}

class _ReceiptDetailBodyState extends State<_ReceiptDetailBody> {
  bool _generating = false;

  pw.Widget _receiptRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    );
  }

  Future<void> _downloadReceipt() async {
    setState(() => _generating = true);
    try {
      final uid = FirebaseService.currentUserId;
      final profile = uid != null ? (await FirebaseService.userDoc(uid).get()).data() : null;
      final patientName = profile?['name'] as String? ?? '';
      final patientPhone = profile?['phone'] as String? ?? '';

      final invoice = widget.invoice;
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                (invoice.clinicName?.isNotEmpty ?? false) ? invoice.clinicName! : AppConstants.appName,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('receipt_pdf_title'.tr(), style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              pw.Text('receipt_pdf_patient'.tr(namedArgs: {'name': patientName})),
              pw.Text('receipt_pdf_phone'.tr(namedArgs: {'phone': patientPhone})),
              pw.Text(
                'receipt_pdf_date'.tr(namedArgs: {'date': invoice.createdAt != null ? DateFormat.yMMMd().format(invoice.createdAt!) : ''}),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: const pw.TableBorder(bottom: pw.BorderSide(width: 0.5)),
                columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text('receipt_pdf_description'.tr(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text('RWF', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  for (final item in invoice.lineItems)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(item.description)),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Text('${item.amountRwf}', textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 12),
              _receiptRow('receipt_pdf_total'.tr(), '${invoice.totalAmountRwf} RWF', bold: true),
              _receiptRow('receipt_pdf_cash_paid'.tr(), '${invoice.cashPaidAmountRwf} RWF'),
              if (invoice.insuranceCoveredAmountRwf > 0)
                _receiptRow(
                  'receipt_pdf_insurance'.tr(namedArgs: {'scheme': invoice.insuranceScheme}),
                  '${invoice.insuranceCoveredAmountRwf} RWF',
                ),
              pw.Divider(),
              _receiptRow('receipt_pdf_balance_due'.tr(), '${invoice.balanceDueRwf} RWF', bold: true),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CliniqnovvaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.clinicName ?? '…',
                        style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    StatusBadge(text: 'invoice_status_${invoice.status}'.tr(), type: widget.badgeType),
                  ],
                ),
                if (invoice.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(DateFormat.yMMMd().format(invoice.createdAt!), style: TextStyle(color: context.appSubtext, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('receipt_line_items_title'.tr(), style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CliniqnovvaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < invoice.lineItems.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == invoice.lineItems.length - 1 ? 0 : 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(invoice.lineItems[i].description, style: TextStyle(color: context.appText, fontSize: 13))),
                        Text(
                          'amount_rwf'.tr(namedArgs: {'amount': NumberFormat.decimalPattern().format(invoice.lineItems[i].amountRwf)}),
                          style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CliniqnovvaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(label: 'receipt_pdf_total'.tr(), value: invoice.totalAmountRwf, bold: true),
                _SummaryRow(label: 'receipt_pdf_cash_paid'.tr(), value: invoice.cashPaidAmountRwf),
                if (invoice.insuranceCoveredAmountRwf > 0)
                  _SummaryRow(
                    label: 'receipt_pdf_insurance'.tr(namedArgs: {'scheme': invoice.insuranceScheme}),
                    value: invoice.insuranceCoveredAmountRwf,
                  ),
                if (invoice.status == 'partial') ...[
                  const Divider(height: 20),
                  _SummaryRow(label: 'receipt_pdf_balance_due'.tr(), value: invoice.balanceDueRwf, bold: true, color: AppColors.errorRed),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          CliniqnovvaButton(
            label: 'action_download_receipt'.tr(),
            isLoading: _generating,
            onPressed: _downloadReceipt,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false, this.color});

  final String label;
  final int value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color ?? context.appText,
      fontSize: 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('amount_rwf'.tr(namedArgs: {'amount': NumberFormat.decimalPattern().format(value)}), style: style),
        ],
      ),
    );
  }
}
