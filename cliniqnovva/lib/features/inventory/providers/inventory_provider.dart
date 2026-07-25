import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/inventory_item_model.dart';

/// Every item in one branch's stock (Part 13 Task 1). Same null-means-
/// server-scope convention as [servicesProvider].
final inventoryListProvider = FutureProvider.autoDispose
    .family<List<InventoryItemModel>, String?>((ref, branchId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/inventory',
        queryParameters: branchId != null ? {'branchId': branchId} : null,
      );
      final data = response.data!['items'] as List<dynamic>;
      return data
          .map((e) => InventoryItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final inventoryItemProvider = FutureProvider.autoDispose
    .family<InventoryItemModel, String>((ref, itemId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/inventory/$itemId',
      );
      return InventoryItemModel.fromJson(
        response.data!['item'] as Map<String, dynamic>,
      );
    });

/// Stock adjustment log (Task 3's DONE CONDITION — viewable history),
/// optionally filtered to one item.
typedef AdjustmentLogParams = ({String? branchId, String? itemId});

final inventoryAdjustmentsProvider = FutureProvider.autoDispose
    .family<List<InventoryAdjustmentModel>, AdjustmentLogParams>((
      ref,
      params,
    ) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/inventory/adjustments',
        queryParameters: {
          if (params.branchId != null) 'branchId': params.branchId,
          if (params.itemId != null) 'itemId': params.itemId,
        },
      );
      final data = response.data!['adjustments'] as List<dynamic>;
      return data
          .map(
            (e) => InventoryAdjustmentModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    });

/// Owns every inventory write action (Part 13) — screens call these instead
/// of hitting ApiService directly.
class InventoryNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _invalidateAll(String itemId) {
    ref.invalidate(inventoryListProvider);
    ref.invalidate(inventoryItemProvider(itemId));
    ref.invalidate(inventoryAdjustmentsProvider);
  }

  Future<void> create({
    required String branchId,
    required String name,
    required String unit,
    String? category,
    required int quantity,
    required int reorderLevel,
    String? expiryDate,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/inventory',
      data: {
        'branchId': branchId,
        'name': name,
        'unit': unit,
        'category': category,
        'quantity': quantity,
        'reorderLevel': reorderLevel,
        'expiryDate': expiryDate,
      },
    );
    ref.invalidate(inventoryListProvider);
    ref.invalidate(inventoryAdjustmentsProvider);
  }

  /// No `quantity` field here — every quantity change goes through
  /// [adjust]/[dispense] so it's always logged. Named [updateItem], not
  /// `update`, so it doesn't collide with AsyncNotifier's own `update()`.
  Future<void> updateItem(
    String itemId, {
    String? name,
    String? unit,
    String? category,
    int? reorderLevel,
    String? expiryDate,
  }) async {
    await ApiService.instance.patch<Map<String, dynamic>>(
      '/api/v1/inventory/$itemId',
      data: {
        'name': ?name,
        'unit': ?unit,
        'category': ?category,
        'reorderLevel': ?reorderLevel,
        'expiryDate': ?expiryDate,
      },
    );
    _invalidateAll(itemId);
  }

  Future<void> setActive(String itemId, bool isActive) async {
    await ApiService.instance.patch<Map<String, dynamic>>(
      '/api/v1/inventory/$itemId/status',
      data: {'isActive': isActive},
    );
    _invalidateAll(itemId);
  }

  /// Manual stock correction (Task 3) — [quantityChange] is SIGNED (positive
  /// to restock, negative to write off breakage/loss), never an absolute
  /// new value.
  Future<void> adjust(
    String itemId, {
    required int quantityChange,
    required String reason,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/inventory/$itemId/adjust',
      data: {'quantityChange': quantityChange, 'reason': reason},
    );
    _invalidateAll(itemId);
  }

  /// Dispense flow (Task 2): select prescription → matching stock item →
  /// deduct. A 409 means the server blocked it as insufficient stock (and
  /// flagged the item for reorder) — nothing was deducted.
  Future<void> dispense({
    required String itemId,
    required int quantity,
    required String patientId,
    required String medicalRecordId,
    required int prescriptionIndex,
    String? reason,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/inventory/dispense',
      data: {
        'itemId': itemId,
        'quantity': quantity,
        'patientId': patientId,
        'medicalRecordId': medicalRecordId,
        'prescriptionIndex': prescriptionIndex,
        'reason': reason,
      },
    );
    _invalidateAll(itemId);
  }
}

final inventoryNotifierProvider = AsyncNotifierProvider<InventoryNotifier, void>(
  InventoryNotifier.new,
);
