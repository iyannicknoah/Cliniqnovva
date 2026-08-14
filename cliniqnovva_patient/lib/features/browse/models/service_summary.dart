/// One deduped service/department tag plus how many public branches offer
/// it — mirrors browse.service.js's `distinctDepartments()`/
/// `departmentCounts()` pairing (`availableDepartments` + the new
/// `departmentCounts` field on the same `/browse/branches` response).
/// Backs the Home screen's service cards ("N Clinics").
class ServiceSummary {
  const ServiceSummary({required this.name, required this.clinicCount});

  final String name;
  final int clinicCount;
}
