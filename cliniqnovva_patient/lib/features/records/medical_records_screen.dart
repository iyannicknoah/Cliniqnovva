import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../browse/providers/browse_provider.dart';
import 'models/medical_record_model.dart';
import 'models/patient_document_model.dart';
import 'providers/records_provider.dart';

/// Pushed on top of the shell — reached from Settings, not a bottom-nav
/// tab. Part 23 Task 1: visit history (newest first) + a flat Documents
/// list (see `PatientDocumentModel`'s doc comment on why it's not grouped
/// per visit). Fully read-only — the patient never edits their own record.
class MedicalRecordsScreen extends ConsumerWidget {
  const MedicalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(medicalRecordsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          'settings_records'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          if (data.records.isEmpty && data.documents.isEmpty) {
            return Center(child: Text('records_empty'.tr(), style: TextStyle(color: context.appSubtext)));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (data.documents.isNotEmpty) ...[
                Text(
                  'records_documents_title'.tr(),
                  style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...data.documents.map((doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DocumentRow(document: doc),
                    )),
                const SizedBox(height: 24),
              ],
              Text(
                'records_visit_history_title'.tr(),
                style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (data.records.isEmpty)
                Text('records_no_visits'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13))
              else
                ...data.records.map((record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VisitCard(record: record),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _VisitCard extends ConsumerWidget {
  const _VisitCard({required this.record});

  final MedicalRecordModel record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = record.doctorId != null ? ref.watch(doctorDetailProvider(record.doctorId!)) : null;
    final doctor = doctorAsync?.valueOrNull;
    final branchAsync = doctor?.branchId != null ? ref.watch(branchDetailProvider(doctor!.branchId!)) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/records/${record.id}'),
      child: CliniqnovvaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.createdAt != null ? DateFormat.yMMMd().format(record.createdAt!) : '…',
                    style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                AppIcon(AppIcons.chevronRight, size: 16, color: context.appSubtext),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              doctor?.name != null ? 'records_doctor_at'.tr(namedArgs: {'doctor': doctor!.name!, 'clinic': branchAsync?.valueOrNull?.branch.name ?? ''}) : '…',
              style: TextStyle(color: context.appSubtext, fontSize: 12),
            ),
            if (record.diagnosis != null && record.diagnosis!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(record.diagnosis!, style: TextStyle(color: context.appText, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatefulWidget {
  const _DocumentRow({required this.document});

  final PatientDocumentModel document;

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _loading = false;

  Future<void> _open() async {
    final patientId = widget.document.patientId;
    if (patientId == null) return;
    setState(() => _loading = true);
    try {
      final result = await fetchDocumentSignedUrl(patientId: patientId, key: widget.document.key);
      await launchUrl(Uri.parse(result.url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _loading ? null : _open,
      child: CliniqnovvaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AppIcon(AppIcons.document, size: 20, color: context.appPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.document.originalName,
                    style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (widget.document.uploadedAt != null)
                    Text(
                      DateFormat.yMMMd().format(widget.document.uploadedAt!),
                      style: TextStyle(color: context.appSubtext, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (_loading)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.appPrimary))
            else
              AppIcon(AppIcons.chevronRight, size: 16, color: context.appSubtext),
          ],
        ),
      ),
    );
  }
}
