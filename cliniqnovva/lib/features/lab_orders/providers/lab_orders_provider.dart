import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/lab_order_model.dart';

/// Worklist query params — null [status]/[patientId] mean "no filter".
/// Same null-means-server-scope convention as [inventoryListProvider].
typedef LabOrdersQuery = ({String? branchId, String? status, String? patientId});

final labOrdersListProvider = FutureProvider.autoDispose
    .family<List<LabOrderModel>, LabOrdersQuery>((ref, query) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/labOrders',
        queryParameters: {
          if (query.branchId != null) 'branchId': query.branchId,
          if (query.status != null) 'status': query.status,
          if (query.patientId != null) 'patientId': query.patientId,
        },
      );
      final data = response.data!['orders'] as List<dynamic>;
      return data
          .map((e) => LabOrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Owns every lab-order write action — screens call these instead of
/// hitting ApiService directly, same pattern as [InventoryNotifier].
///
/// Unlike [InventoryNotifier], this notifier does NOT invalidate
/// [labOrdersListProvider] itself — that family provider is keyed on
/// (branchId, status, patientId), and a notifier has no way to know which
/// combinations a caller currently has on screen. Screens invalidate their
/// own specific query key after a write (see lab_orders_screen.dart and
/// patient_lab_orders_section.dart) instead.
class LabOrdersNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<LabOrderModel> order({
    required String branchId,
    required String patientId,
    String? appointmentId,
    String? medicalRecordId,
    required String testName,
    String? testCategory,
    int priceRwf = 0,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/labOrders',
      data: {
        'branchId': branchId,
        'patientId': patientId,
        'appointmentId': appointmentId,
        'medicalRecordId': medicalRecordId,
        'testName': testName,
        'testCategory': testCategory,
        'priceRwf': priceRwf,
      },
    );
    return LabOrderModel.fromJson(
      response.data!['order'] as Map<String, dynamic>,
    );
  }

  Future<void> markCollected(String orderId) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/labOrders/$orderId/collect',
    );
  }

  Future<void> recordResult(
    String orderId, {
    required String resultValue,
    String? resultUnit,
    String? resultNotes,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/labOrders/$orderId/result',
      data: {
        'resultValue': resultValue,
        'resultUnit': resultUnit,
        'resultNotes': resultNotes,
      },
    );
  }

  Future<void> markReviewed(String orderId) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/labOrders/$orderId/review',
    );
  }
}

final labOrdersNotifierProvider = AsyncNotifierProvider<LabOrdersNotifier, void>(
  LabOrdersNotifier.new,
);
