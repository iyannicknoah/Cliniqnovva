/// Mirrors the backend's `inventory` document (spec section 6.9, Part 13).
class InventoryItemModel {
  const InventoryItemModel({
    required this.id,
    required this.clinicId,
    required this.branchId,
    required this.name,
    required this.unit,
    this.category,
    required this.quantity,
    required this.reorderLevel,
    this.expiryDate,
    this.isActive = true,
    this.needsReorder = false,
    this.isExpired = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String clinicId;
  final String branchId;
  final String name;
  final String unit;
  final String? category;
  final int quantity;
  final int reorderLevel;

  /// ISO date string 'YYYY-MM-DD', or null if this item doesn't expire.
  final String? expiryDate;
  final bool isActive;

  /// Server-computed: quantity <= reorderLevel.
  final bool needsReorder;

  /// Server-computed: expiryDate is in the past (Africa/Kigali). Task 1:
  /// "expired excluded from dispensing" — the dispense flow must filter
  /// these out client-side too, not just rely on the server's block.
  final bool isExpired;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      category: json['category'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      reorderLevel: json['reorderLevel'] as int? ?? 0,
      expiryDate: json['expiryDate'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      needsReorder: json['needsReorder'] as bool? ?? false,
      isExpired: json['isExpired'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Mirrors one `inventoryAdjustments` log entry — Task 3's "every change
/// logged with reason + staff ID".
class InventoryAdjustmentModel {
  const InventoryAdjustmentModel({
    required this.id,
    required this.itemId,
    required this.quantityChange,
    required this.quantityAfter,
    required this.type,
    required this.reason,
    this.staffId,
    this.patientId,
    this.createdAt,
  });

  final String id;
  final String itemId;

  /// Signed — positive for a restock/initial stock, negative for a
  /// dispense or a manual write-down.
  final int quantityChange;
  final int quantityAfter;

  /// 'initial' | 'manual' | 'dispense'.
  final String type;
  final String reason;
  final String? staffId;
  final String? patientId;
  final DateTime? createdAt;

  factory InventoryAdjustmentModel.fromJson(Map<String, dynamic> json) {
    return InventoryAdjustmentModel(
      id: json['id'] as String,
      itemId: json['itemId'] as String? ?? '',
      quantityChange: json['quantityChange'] as int? ?? 0,
      quantityAfter: json['quantityAfter'] as int? ?? 0,
      type: json['type'] as String? ?? 'manual',
      reason: json['reason'] as String? ?? '',
      staffId: json['staffId'] as String?,
      patientId: json['patientId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
