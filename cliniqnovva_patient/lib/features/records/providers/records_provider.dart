import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/linked_patient_ids_provider.dart';
import '../../../core/services/api_service.dart';
import '../models/invoice_model.dart';
import '../models/medical_record_model.dart';
import '../models/patient_document_model.dart';

class MedicalRecordsData {
  const MedicalRecordsData({required this.records, required this.documents});

  final List<MedicalRecordModel> records;
  final List<PatientDocumentModel> documents;
}

/// GET /api/v1/patients/:patientId/medical-records, once per linked clinic
/// (Part 23 Task 3's endpoint is deliberately single-clinic, same "fan out
/// + merge client-side" shape as My Bookings, Part 22), merged into one
/// list sorted newest-first. Documents have no visit/appointment linkage in
/// this schema (see `PatientDocumentModel`'s own doc comment) — the merged
/// `documents` list is flat across every clinic too, not grouped per visit.
final medicalRecordsProvider = FutureProvider.autoDispose<MedicalRecordsData>((ref) async {
  final linkedIds = await ref.watch(linkedPatientIdsProvider.future);
  if (linkedIds.isEmpty) return const MedicalRecordsData(records: [], documents: []);

  final results = await Future.wait(
    linkedIds.map((id) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/patients/$id/medical-records');
      final data = response.data!;
      return (
        records: (data['records'] as List).map((e) => MedicalRecordModel.fromJson(e as Map<String, dynamic>)).toList(),
        documents: (data['documents'] as List).map((e) => PatientDocumentModel.fromJson(e as Map<String, dynamic>)).toList(),
      );
    }),
  );

  final records = results.expand((r) => r.records).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  final documents = results.expand((r) => r.documents).toList()
    ..sort((a, b) => (b.uploadedAt ?? DateTime(0)).compareTo(a.uploadedAt ?? DateTime(0)));

  return MedicalRecordsData(records: records, documents: documents);
});

/// GET /:patientId/documents/:key/signed-url, called fresh on every tap —
/// deliberately a plain function, not a cached FutureProvider, since the
/// whole point (Part 23 DONE CONDITION) is "a fresh signed URL... never a
/// permanent link" reused across views. `patientId` here must be the
/// SPECIFIC linked record the document actually belongs to (embedded in
/// the document's own `key`, e.g. `patients/{patientId}/documents/...`) —
/// callers resolve it from the fetched document/record, never guess.
Future<({String url, String? contentType, String? originalName})> fetchDocumentSignedUrl({
  required String patientId,
  required String key,
}) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/patients/$patientId/documents/${Uri.encodeComponent(key)}/signed-url',
  );
  final data = response.data!;
  return (url: data['url'] as String, contentType: data['contentType'] as String?, originalName: data['originalName'] as String?);
}

/// GET /api/v1/patients/:patientId/invoices, once per linked clinic, merged
/// newest-first — the Receipts screen. Same fan-out shape as
/// [medicalRecordsProvider]/`myBookingsProvider`.
final invoicesProvider = FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final linkedIds = await ref.watch(linkedPatientIdsProvider.future);
  if (linkedIds.isEmpty) return [];

  final results = await Future.wait(
    linkedIds.map((id) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/patients/$id/invoices');
      return (response.data!['invoices'] as List).map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>)).toList();
    }),
  );

  final invoices = results.expand((list) => list).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return invoices;
});
