import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/invoice_model.dart';

/// Filter params for [invoicesListProvider] — Part 12 Task 2's "filter by
/// status/date".
typedef InvoiceListParams = ({
  String? branchId,
  String? status,
  String? dateFrom,
  String? dateTo,
});

final invoicesListProvider = FutureProvider.autoDispose
    .family<List<InvoiceModel>, InvoiceListParams>((ref, params) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/invoices',
        queryParameters: {
          if (params.branchId != null) 'branchId': params.branchId,
          if (params.status != null) 'status': params.status,
          if (params.dateFrom != null) 'dateFrom': params.dateFrom,
          if (params.dateTo != null) 'dateTo': params.dateTo,
        },
      );
      final data = response.data!['invoices'] as List<dynamic>;
      return data
          .map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final invoiceDetailProvider = FutureProvider.autoDispose
    .family<InvoiceModel, String>((ref, invoiceId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/invoices/$invoiceId',
      );
      return InvoiceModel.fromJson(
        response.data!['invoice'] as Map<String, dynamic>,
      );
    });

/// Owns every invoice write action (Part 12) — screens call these instead
/// of hitting ApiService directly.
class InvoicesNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _invalidateAll(String invoiceId) {
    ref.invalidate(invoicesListProvider);
    ref.invalidate(invoiceDetailProvider(invoiceId));
  }

  Future<InvoiceModel> create({
    required String branchId,
    required String patientId,
    String? appointmentId,
    required List<LineItem> lineItems,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/invoices',
      data: {
        'branchId': branchId,
        'patientId': patientId,
        'appointmentId': appointmentId,
        'lineItems': lineItems.map((li) => li.toJson()).toList(),
      },
    );
    ref.invalidate(invoicesListProvider);
    return InvoiceModel.fromJson(
      response.data!['invoice'] as Map<String, dynamic>,
    );
  }

  /// The total is always server-recalculated from [lineItems] — this never
  /// sends a total (Part 12 DONE CONDITION: "Total always
  /// server-recalculated").
  Future<void> updateLineItems(String invoiceId, List<LineItem> lineItems) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/invoices/$invoiceId/line-items',
      data: {'lineItems': lineItems.map((li) => li.toJson()).toList()},
    );
    _invalidateAll(invoiceId);
  }

  /// Additive — never overwrites the running balance. A 400 here means the
  /// server rejected it as exceeding the invoice total.
  Future<void> recordCashPayment(String invoiceId, int amountRwf) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/invoices/$invoiceId/record-cash-payment',
      data: {'amountRwf': amountRwf},
    );
    _invalidateAll(invoiceId);
  }

  Future<void> recordInsurance(
    String invoiceId, {
    required int amountRwf,
    required String scheme,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/invoices/$invoiceId/record-insurance',
      data: {'amountRwf': amountRwf, 'scheme': scheme},
    );
    _invalidateAll(invoiceId);
  }

  /// The ONLY removal path — never a delete (Part 12 DONE CONDITION:
  /// "Invoice never deletable once paid, only voidable").
  Future<void> voidInvoice(String invoiceId, String reason) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/invoices/$invoiceId/void',
      data: {'reason': reason},
    );
    _invalidateAll(invoiceId);
  }
}

final invoicesNotifierProvider = AsyncNotifierProvider<InvoicesNotifier, void>(
  InvoicesNotifier.new,
);
