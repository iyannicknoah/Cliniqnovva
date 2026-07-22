/// A branch under an [Organization] (Part 3 Task 3's read-only branch list;
/// full branch management is Part 6's scope).
class Branch {
  const Branch({required this.id, required this.name, this.address, this.phone, this.isActive = true});

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Mirrors the backend's `organizations` document shape (Part 3).
/// [branchLimit] is null for the enterprise plan (unlimited branches).
/// [branches] is only populated by the detail endpoint, not the list one.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.subscriptionPlan,
    required this.branchLimit,
    required this.branchCount,
    required this.isActive,
    required this.createdAt,
    this.ownerContactName,
    this.ownerContactPhone,
    this.branches = const [],
  });

  final String id;
  final String name;
  final String subscriptionPlan;
  final int? branchLimit;
  final int branchCount;
  final bool isActive;
  final DateTime? createdAt;
  final String? ownerContactName;
  final String? ownerContactPhone;
  final List<Branch> branches;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      subscriptionPlan: json['subscriptionPlan'] as String? ?? 'basic',
      branchLimit: json['branchLimit'] as int?,
      branchCount: json['branchCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      ownerContactName: json['ownerContactName'] as String?,
      ownerContactPhone: json['ownerContactPhone'] as String?,
      branches:
          (json['branches'] as List<dynamic>?)?.map((b) => Branch.fromJson(b as Map<String, dynamic>)).toList() ??
          const [],
    );
  }

  String get branchLimitLabel => branchLimit == null ? 'Unlimited' : '$branchCount / $branchLimit';
}
