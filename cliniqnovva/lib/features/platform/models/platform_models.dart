/// Part 5 Task 2 — platform-wide metrics, for Cliniqnovva's own business
/// visibility only, never shown to any organization.
class PlatformMetrics {
  const PlatformMetrics({
    required this.totalOrganizations,
    required this.totalBranches,
    required this.totalActiveStaff,
    required this.totalPatients,
    required this.totalAppointmentsThisMonth,
  });

  final int totalOrganizations;
  final int totalBranches;
  final int totalActiveStaff;
  final int totalPatients;
  final int totalAppointmentsThisMonth;

  factory PlatformMetrics.fromJson(Map<String, dynamic> json) {
    return PlatformMetrics(
      totalOrganizations: json['totalOrganizations'] as int? ?? 0,
      totalBranches: json['totalBranches'] as int? ?? 0,
      totalActiveStaff: json['totalActiveStaff'] as int? ?? 0,
      totalPatients: json['totalPatients'] as int? ?? 0,
      totalAppointmentsThisMonth: json['totalAppointmentsThisMonth'] as int? ?? 0,
    );
  }
}

class BranchSearchResult {
  const BranchSearchResult({required this.id, required this.name, this.organizationName, this.address});

  final String id;
  final String name;
  final String? organizationName;
  final String? address;

  factory BranchSearchResult.fromJson(Map<String, dynamic> json) => BranchSearchResult(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    organizationName: json['organizationName'] as String?,
    address: json['address'] as String?,
  );
}

class StaffSearchResult {
  const StaffSearchResult({required this.id, required this.name, required this.role, this.organizationName, this.email});

  final String id;
  final String name;
  final String role;
  final String? organizationName;
  final String? email;

  factory StaffSearchResult.fromJson(Map<String, dynamic> json) => StaffSearchResult(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    organizationName: json['organizationName'] as String?,
    email: json['email'] as String?,
  );
}

/// Part 5 Task 1 — cross-organization branch/staff search results.
class PlatformSearchResults {
  const PlatformSearchResults({required this.branches, required this.staff});

  final List<BranchSearchResult> branches;
  final List<StaffSearchResult> staff;

  factory PlatformSearchResults.fromJson(Map<String, dynamic> json) => PlatformSearchResults(
    branches: (json['branches'] as List<dynamic>? ?? [])
        .map((e) => BranchSearchResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    staff: (json['staff'] as List<dynamic>? ?? []).map((e) => StaffSearchResult.fromJson(e as Map<String, dynamic>)).toList(),
  );

  bool get isEmpty => branches.isEmpty && staff.isEmpty;
}

/// Part 5 Task 1 — one platform-wide audit log entry (all organizations
/// combined, filterable server-side).
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    this.actorId,
    this.actorRole,
    this.targetCollection,
    this.targetId,
    this.organizationId,
    this.timestamp,
  });

  final String id;
  final String action;
  final String? actorId;
  final String? actorRole;
  final String? targetCollection;
  final String? targetId;
  final String? organizationId;
  final DateTime? timestamp;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: json['id'] as String,
    action: json['action'] as String? ?? '',
    actorId: json['actorId'] as String?,
    actorRole: json['actorRole'] as String?,
    targetCollection: json['targetCollection'] as String?,
    targetId: json['targetId'] as String?,
    organizationId: json['organizationId'] as String?,
    timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp'] as String) : null,
  );
}
