import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../browse/providers/browse_provider.dart';
import 'models/medical_record_model.dart';
import 'providers/records_provider.dart';

/// Pushed on top of the shell. Part 23 Task 1's visit detail: full
/// diagnosis, prescriptions laid out clearly (not a wall of text), and the
/// doctor's notes. No "patient-visible" flag exists on this schema (see
/// `patients.service.js#getMedicalRecordsAndDocumentsForPatient`'s doc
/// comment) — every note is shown as-is, per Part 23's own explicit
/// instruction for that case.
class MedicalRecordDetailScreen extends ConsumerWidget {
  const MedicalRecordDetailScreen({super.key, required this.recordId});

  final String recordId;

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
          onPressed: () => context.canPop() ? context.pop() : context.go('/records'),
        ),
        title: Text(
          'records_visit_detail_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
        data: (data) {
          MedicalRecordModel? record;
          for (final r in data.records) {
            if (r.id == recordId) {
              record = r;
              break;
            }
          }
          if (record == null) {
            return Center(child: Text('records_visit_not_found'.tr(), style: TextStyle(color: context.appSubtext)));
          }
          return _RecordDetailBody(record: record);
        },
      ),
    );
  }
}

class _RecordDetailBody extends ConsumerWidget {
  const _RecordDetailBody({required this.record});

  final MedicalRecordModel record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = record.doctorId != null ? ref.watch(doctorDetailProvider(record.doctorId!)) : null;
    final doctor = doctorAsync?.valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CliniqnovvaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.createdAt != null ? DateFormat.yMMMEd().format(record.createdAt!) : '',
                  style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (doctor?.name != null) ...[
                  const SizedBox(height: 4),
                  Text('Dr. ${doctor!.name}', style: TextStyle(color: context.appSubtext, fontSize: 13)),
                ],
              ],
            ),
          ),
          if (record.diagnosis != null && record.diagnosis!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'records_diagnosis_title'.tr(),
              style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CliniqnovvaCard(
              child: Text(record.diagnosis!, style: TextStyle(color: context.appText, fontSize: 13, height: 1.5)),
            ),
          ],
          if (record.prescriptions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'records_prescriptions_title'.tr(),
              style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CliniqnovvaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < record.prescriptions.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == record.prescriptions.length - 1 ? 0 : 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppIcon(AppIcons.receipt, size: 16, color: context.appPrimary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.prescriptions[i].medicineName,
                                  style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                if (record.prescriptions[i].dosage != null || record.prescriptions[i].duration != null)
                                  Text(
                                    [record.prescriptions[i].dosage, record.prescriptions[i].duration]
                                        .where((s) => s != null && s.isNotEmpty)
                                        .join(' · '),
                                    style: TextStyle(color: context.appSubtext, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'records_notes_title'.tr(),
              style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CliniqnovvaCard(
              child: Text(record.notes!, style: TextStyle(color: context.appText, fontSize: 13, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }
}
