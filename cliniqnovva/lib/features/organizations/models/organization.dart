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

/// One entry in an [Organization]'s `subscriptionPaymentHistory` (Part 4 —
/// cash-only record-keeping, there is no payment gateway).
class SubscriptionPayment {
  const SubscriptionPayment({required this.date, required this.amountRwf, this.note, this.recordedBy});

  final DateTime? date;
  final int amountRwf;
  final String? note;
  final String? recordedBy;

  factory SubscriptionPayment.fromJson(Map<String, dynamic> json) {
    return SubscriptionPayment(
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
      amountRwf: (json['amountRwf'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      recordedBy: json['recordedBy'] as String?,
    );
  }
}

/// Mirrors the backend's `organizations` document shape (Part 3 + Part 4).
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
    required this.billingCycle,
    required this.subscriptionAmountRwf,
    this.nextDueDate,
    this.paymentHistory = const [],
    required this.billingStatus,
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

  /// Part 4: subscription/billing tracking (cash-only, no gateway).
  final String billingCycle; // 'monthly' | 'quarterly'
  final int subscriptionAmountRwf;
  final DateTime? nextDueDate;
  final List<SubscriptionPayment> paymentHistory;

  /// Computed server-side on every read (never auto-suspends):
  /// 'paid' | 'dueSoon' | 'overdue' | 'unknown'.
  final String billingStatus;

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
      billingCycle: json['billingCycle'] as String? ?? 'monthly',
      subscriptionAmountRwf: (json['subscriptionAmountRwf'] as num?)?.toInt() ?? 0,
      nextDueDate: json['nextDueDate'] != null ? DateTime.tryParse(json['nextDueDate'] as String) : null,
      paymentHistory:
          (json['subscriptionPaymentHistory'] as List<dynamic>?)
              ?.map((p) => SubscriptionPayment.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      billingStatus: json['billingStatus'] as String? ?? 'unknown',
    );
  }

  String get branchLimitLabel => branchLimit == null ? 'Unlimited' : '$branchCount / $branchLimit';

  /// Monthly-normalized revenue for this organization (quarterly ÷ 3), used
  /// for the Billing screen's "Total monthly revenue" MetricCard.
  double get monthlyEquivalentRwf => billingCycle == 'quarterly' ? subscriptionAmountRwf / 3 : subscriptionAmountRwf.toDouble();
}
