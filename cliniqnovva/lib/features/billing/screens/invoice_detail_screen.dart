import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../patients/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../models/invoice_model.dart';
import '../providers/invoices_provider.dart';

const _statusLabels = {
  AppConstants.invoiceUnpaid: 'Unpaid',
  AppConstants.invoicePartial: 'Partial',
  AppConstants.invoicePaid: 'Paid',
  AppConstants.invoiceVoided: 'Voided',
};

const _insuranceSchemeLabels = {
  AppConstants.insuranceMutuelle: 'Mutuelle de Santé',
  AppConstants.insuranceRssb: 'RSSB',
  AppConstants.insuranceRadiant: 'Radiant Insurance Company',
  AppConstants.insuranceOldMutual: 'Old Mutual Rwanda',
  AppConstants.insuranceBritam: 'Britam Insurance Company (Rwanda) Ltd',
  AppConstants.insuranceSonarwa: 'SONARWA General Insurance Ltd',
  AppConstants.insuranceSanlam: 'Sanlam Assurances Générales Ltd',
  AppConstants.insurancePrime: 'PRIME Insurance Ltd',
  AppConstants.insuranceMua: 'MUA Rwanda',
  AppConstants.insuranceBkGeneral: 'BK General Insurance Company Ltd',
  AppConstants.insuranceMayfair: 'Mayfair Insurance Company Rwanda Ltd',
  AppConstants.insurancePrivate: 'Other private insurer',
};

BadgeType _badgeTypeFor(String status) => switch (status) {
  AppConstants.invoicePaid => BadgeType.success,
  AppConstants.invoiceVoided => BadgeType.error,
  AppConstants.invoicePartial => BadgeType.info,
  _ => BadgeType.warning,
};

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Part 12 Task 3's invoice view/edit UI. 2026-08-15, explicit user
/// instruction — switched from a full routed page (`/billing/:invoiceId`) to
/// a centered modal dialog, matching Register Patient/Add Branch's pattern
/// (`Material` + rounded `AppTheme.cardRadius` corners, fade+scale
/// transition). Editable line items, server-recalculated total,
/// cash/insurance recording (overflow-guarded server-side), void with a
/// reason, and a printable/downloadable PDF receipt.
Future<void> showInvoiceDetailPanel(
  BuildContext context, {
  required String invoiceId,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Invoice',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        Center(child: _InvoiceDetailPanel(invoiceId: invoiceId)),
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

class _InvoiceDetailPanel extends ConsumerWidget {
  const _InvoiceDetailPanel({required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return Material(
      color: context.appCard,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: context.appBorder),
        ),
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: invoiceAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(60),
            child: LoadingWidget(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: TextStyle(color: context.appSubtext)),
          ),
          data: (invoice) => SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _InvoiceBody(invoice: invoice),
          ),
        ),
      ),
    );
  }
}

class _InvoiceBody extends ConsumerWidget {
  const _InvoiceBody({required this.invoice});

  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voided = invoice.status == AppConstants.invoiceVoided;
    final patientAsync = ref.watch(patientDetailProvider(invoice.patientId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice',
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  patientAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (patient) => Text(
                      '${patient.name} · ${patient.phone}',
                      style: TextStyle(
                        color: context.appSubtext,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Text(
                    'Created ${_formatDate(invoice.createdAt)}',
                    style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            StatusBadge(
              text: _statusLabels[invoice.status] ?? invoice.status,
              type: _badgeTypeFor(invoice.status),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const AppIcon(AppIcons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _LineItemsCard(invoice: invoice, editable: !voided),
        const SizedBox(height: 20),
        _SummaryCard(invoice: invoice),
        if (!voided) ...[
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _RecordCashCard(invoiceId: invoice.id)),
              const SizedBox(width: 16),
              Expanded(child: _RecordInsuranceCard(invoiceId: invoice.id)),
            ],
          ),
        ],
        if (voided && invoice.voidReason != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pillRedBg,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Text(
              'Voided: ${invoice.voidReason}',
              style: const TextStyle(
                color: AppColors.pillRedText,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: CliniqnovvaButton(
                label: 'Print / Download Receipt',
                onPressed: () => _printReceipt(context, ref, invoice),
              ),
            ),
            const SizedBox(width: 12),
            if (!voided)
              CliniqnovvaButton.text(
                label: 'Void Invoice',
                color: context.appSubtext,
                onPressed: () => _confirmVoid(context, ref, invoice),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel invoice,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Void this invoice?'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This invoice is never deleted — it stays on record as voided, with the reason below.',
              ),
              const SizedBox(height: 12),
              CliniqnovvaTextField(
                label: 'Reason',
                controller: reasonController,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;

    try {
      await runWithFeedback(
        context,
        () => ref
            .read(invoicesNotifierProvider.notifier)
            .voidInvoice(invoice.id, reason),
        loadingMessage: 'Voiding…',
        successMessage: 'Invoice voided.',
      );
    } catch (_) {
      // runWithFeedback already surfaced the server's reason in the error SnackBar.
    }
  }

  /// Previously fired-and-forgot — no loading state, and any failure (a
  /// patient lookup error, or the `printing` package's pdf.js failing to
  /// load on web) was silently swallowed, which is exactly why the button
  /// could look "broken" with zero feedback (2026-07-26, explicit user
  /// instruction to fix this and surface a loading indicator).
  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel invoice,
  ) async {
    try {
      await runWithFeedback(
        context,
        () async {
          final patient = await ref.read(
            patientDetailProvider(invoice.patientId).future,
          );
          await _generateReceiptPdf(invoice, patient);
        },
        loadingMessage: 'Preparing receipt…',
        successMessage: 'Receipt ready.',
      );
    } catch (_) {
      // runWithFeedback already surfaced the error in the SnackBar.
    }
  }
}

Future<void> _generateReceiptPdf(
  InvoiceModel invoice,
  PatientModel patient,
) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            // The receipt is issued BY the clinic, not by Cliniqnovva (the
            // software) — fall back to the app name only if a clinic
            // somehow has no name on record (2026-07-26, explicit user
            // instruction).
            invoice.clinicName?.isNotEmpty == true
                ? invoice.clinicName!
                : AppConstants.appName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Receipt', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
          pw.Text('Patient: ${patient.name}'),
          pw.Text('Phone: ${patient.phone}'),
          pw.Text('Date: ${_formatDate(invoice.createdAt)}'),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder(bottom: const pw.BorderSide(width: 0.5)),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(
                      'Description',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(
                      'RWF',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              for (final item in invoice.lineItems)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(item.description),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text(
                        '${item.amountRwf}',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          _receiptRow('Total', '${invoice.totalAmountRwf} RWF', bold: true),
          _receiptRow('Cash paid', '${invoice.cashPaidAmountRwf} RWF'),
          if (invoice.insuranceCoveredAmountRwf > 0)
            _receiptRow(
              'Insurance (${invoice.insuranceScheme})',
              '${invoice.insuranceCoveredAmountRwf} RWF',
            ),
          pw.Divider(),
          _receiptRow(
            'Balance due',
            '${invoice.balanceDueRwf} RWF',
            bold: true,
          ),
        ],
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

pw.Widget _receiptRow(String label, String value, {bool bold = false}) {
  final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    ),
  );
}

class _EditableLineItem {
  _EditableLineItem({String description = '', String amount = ''})
    : descriptionController = TextEditingController(text: description),
      amountController = TextEditingController(text: amount);

  final TextEditingController descriptionController;
  final TextEditingController amountController;
}

class _LineItemsCard extends ConsumerStatefulWidget {
  const _LineItemsCard({required this.invoice, required this.editable});

  final InvoiceModel invoice;
  final bool editable;

  @override
  ConsumerState<_LineItemsCard> createState() => _LineItemsCardState();
}

class _LineItemsCardState extends ConsumerState<_LineItemsCard> {
  List<_EditableLineItem>? _rows;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    _rows ??= widget.invoice.lineItems
        .map(
          (li) => _EditableLineItem(
            description: li.description,
            amount: li.amountRwf.toString(),
          ),
        )
        .toList();
    final rows = _rows!;

    final liveTotal = rows.fold<int>(
      0,
      (sum, r) => sum + (int.tryParse(r.amountController.text.trim()) ?? 0),
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
                  'Line items',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.editable)
                CliniqnovvaButton.text(
                  label: '+ Add line',
                  color: context.appText,
                  onPressed: () =>
                      setState(() => rows.add(_EditableLineItem())),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: IgnorePointer(
                      ignoring: !widget.editable,
                      child: TextField(
                        controller: rows[i].descriptionController,
                        enabled: widget.editable,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: context.appText, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Description',
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
                            borderSide: BorderSide(color: context.appBorder),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: !widget.editable,
                      child: TextField(
                        controller: rows[i].amountController,
                        enabled: widget.editable,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: context.appText, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'RWF',
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
                            borderSide: BorderSide(color: context.appBorder),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.editable && rows.length > 1) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: AppIcon(
                        AppIcons.trash,
                        size: 15,
                        color: context.appSubtext,
                      ),
                      onPressed: () => setState(() => rows.removeAt(i)),
                    ),
                  ],
                ],
              ),
            ),
          if (widget.editable) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(color: context.appSubtext, fontSize: 13),
                ),
                Text(
                  '$liveTotal RWF',
                  style: TextStyle(
                    color: context.appText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: CliniqnovvaButton(
                label: 'Save line items',
                isLoading: _saving,
                onPressed: _saving ? null : () => _save(rows),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(List<_EditableLineItem> rows) async {
    final items = <LineItem>[];
    for (final row in rows) {
      final description = row.descriptionController.text.trim();
      final amount = int.tryParse(row.amountController.text.trim());
      if (description.isEmpty || amount == null || amount < 0) {
        setState(
          () => _error =
              'Every line needs a description and a whole-number RWF amount.',
        );
        return;
      }
      items.add(LineItem(description: description, amountRwf: amount));
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(invoicesNotifierProvider.notifier)
          .updateLineItems(widget.invoice.id, items);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Line items saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.invoice});

  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            label: 'Total',
            value: invoice.totalAmountRwf,
            bold: true,
          ),
          _SummaryRow(label: 'Cash paid', value: invoice.cashPaidAmountRwf),
          _SummaryRow(
            label: 'Insurance covered (${invoice.insuranceScheme})',
            value: invoice.insuranceCoveredAmountRwf,
          ),
          Divider(height: 20, color: context.appBorder),
          _SummaryRow(
            label: 'Balance due',
            value: invoice.balanceDueRwf,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final int value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? context.appText : context.appSubtext,
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            '$value RWF',
            style: TextStyle(
              color: context.appText,
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCashCard extends ConsumerStatefulWidget {
  const _RecordCashCard({required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<_RecordCashCard> createState() => _RecordCashCardState();
}

class _RecordCashCardState extends ConsumerState<_RecordCashCard> {
  final _amountController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a positive whole number of RWF.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await runWithFeedback(
        context,
        () => ref
            .read(invoicesNotifierProvider.notifier)
            .recordCashPayment(widget.invoiceId, amount),
        loadingMessage: 'Recording payment…',
        successMessage: 'Cash payment recorded.',
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _amountController.clear();
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record Cash Payment',
            style: TextStyle(
              color: context.appText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          CliniqnovvaTextField(
            label: 'Amount (RWF)',
            controller: _amountController,
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.pillRedText,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CliniqnovvaButton(
              label: 'Record',
              isLoading: _saving,
              onPressed: _saving ? null : _record,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordInsuranceCard extends ConsumerStatefulWidget {
  const _RecordInsuranceCard({required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<_RecordInsuranceCard> createState() =>
      _RecordInsuranceCardState();
}

class _RecordInsuranceCardState extends ConsumerState<_RecordInsuranceCard> {
  final _amountController = TextEditingController();
  String _scheme = AppConstants.insuranceMutuelle;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a positive whole number of RWF.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await runWithFeedback(
        context,
        () => ref
            .read(invoicesNotifierProvider.notifier)
            .recordInsurance(
              widget.invoiceId,
              amountRwf: amount,
              scheme: _scheme,
            ),
        loadingMessage: 'Recording coverage…',
        successMessage: 'Insurance coverage recorded.',
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _amountController.clear();
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record Insurance Coverage',
            style: TextStyle(
              color: context.appText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scheme',
            style: TextStyle(
              color: context.appText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          AppSelect(
            value: _scheme,
            options: [
              for (final e in _insuranceSchemeLabels.entries)
                AppSelectOption(value: e.key, label: e.value),
            ],
            onChanged: (v) => setState(() => _scheme = v ?? _scheme),
          ),
          const SizedBox(height: 12),
          CliniqnovvaTextField(
            label: 'Amount covered (RWF)',
            controller: _amountController,
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.pillRedText,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CliniqnovvaButton(
              label: 'Record',
              isLoading: _saving,
              onPressed: _saving ? null : _record,
            ),
          ),
        ],
      ),
    );
  }
}
