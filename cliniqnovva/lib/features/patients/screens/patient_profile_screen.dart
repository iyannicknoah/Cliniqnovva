import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../../shared/providers/connectivity_provider.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../lab_orders/widgets/patient_lab_orders_section.dart';
import '../models/medical_record_model.dart';
import '../models/patient_document_model.dart';
import '../models/patient_model.dart';
import '../providers/patients_provider.dart';
import '../widgets/patient_form_fields.dart';

const _monthAbbr = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime d) => '${_monthAbbr[d.month]} ${d.day}, ${d.year}';
String _formatDateTime(DateTime d) =>
    '${_formatDate(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Part 9 Task 3 — /patients/:id. Profile | Medical Records | Documents.
/// The latter two tabs render whatever the API actually sent — a
/// receptionist's [PatientModel.medicalRecords]/[documents] are null
/// because the server omitted those keys, not because the client hid them.
class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    if (id == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: Center(
          child: Text('No patient id.', style: TextStyle(color: context.appSubtext)),
        ),
      );
    }

    final claims = ref.watch(userClaimsProvider);
    final patientAsync = ref.watch(patientDetailProvider(id));

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.appSubtext)),
        ),
        data: (claimsData) {
          final role = claimsData?['role'] as String? ?? '';
          // Lab Orders tab (2026-07-29) — Doctor/Nurse/Laboratorian only,
          // same role set that has any interaction with a lab order at all
          // (order/perform/review). Laboratorian never reaches this screen
          // via nav today (see app_shell.dart), but the tab still works if
          // reached directly, and Doctor/Nurse do reach it via /patients.
          final canSeeLabOrders =
              role == AppConstants.roleDoctor ||
              role == AppConstants.roleNurse ||
              role == AppConstants.roleLaboratorian;
          final tabLabels = [
            'Profile',
            'Medical Records',
            'Documents',
            if (canSeeLabOrders) 'Lab Orders',
          ];
          return patientAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => Center(
              child: Text('$e', style: TextStyle(color: context.appSubtext)),
            ),
            data: (patient) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileHeader(patient: patient),
                      const SizedBox(height: 28),
                      SegmentedTabs(
                        labels: tabLabels,
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                      const SizedBox(height: 24),
                      switch (_tab) {
                        0 => _ProfileTab(patient: patient),
                        1 => _MedicalRecordsTab(patient: patient, role: role),
                        2 => _DocumentsTab(patient: patient, role: role),
                        _ => PatientLabOrdersSection(
                          patientId: patient.id,
                          branchId: patient.branchId,
                          role: role,
                        ),
                      },
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (patient.dateOfBirth != null)
        '${patient.ageInYears} yrs (${_formatDate(patient.dateOfBirth!)})',
      if (patient.gender != null) patient.gender!,
      patient.phone,
    ];

    return Row(
      children: [
        AvatarWidget(firstName: patient.name, size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.name,
                style: TextStyle(
                  color: context.appText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                parts.join(' · '),
                style: TextStyle(color: context.appSubtext, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const TopBarActions(),
      ],
    );
  }
}

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab({required this.patient});

  final PatientModel patient;

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  late final _nameController = TextEditingController(text: widget.patient.name);
  late final _phoneController = TextEditingController(text: widget.patient.phone);
  late final _nationalIdController = TextEditingController(
    text: widget.patient.nationalId ?? '',
  );
  late final _emergencyNameController = TextEditingController(
    text: widget.patient.emergencyContact?.name ?? '',
  );
  late final _emergencyPhoneController = TextEditingController(
    text: widget.patient.emergencyContact?.phone ?? '',
  );
  final _addressKey = GlobalKey<PatientAddressFormState>();

  late DateTime? _dob = widget.patient.dateOfBirth;
  late String? _gender = widget.patient.gender;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final nationalId = _nationalIdController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Phone is required.');
      return;
    }
    if (nationalId.isNotEmpty && !RegExp(r'^\d{16}$').hasMatch(nationalId)) {
      setState(() => _error = 'National ID must be exactly 16 digits.');
      return;
    }
    if (!_addressKey.currentState!.isValid) {
      setState(
        () => _error =
            'Enter both province and district, or leave the address blank.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await runWithFeedback(
        context,
        () => ref.read(patientsNotifierProvider.notifier).updateProfile(
          widget.patient.id,
          {
            'name': name,
            'phone': phone,
            'dateOfBirth': _dob?.toIso8601String(),
            'gender': _gender,
            'nationalId': nationalId.isEmpty ? null : nationalId,
            'emergencyContact':
                _emergencyNameController.text.trim().isEmpty &&
                    _emergencyPhoneController.text.trim().isEmpty
                ? null
                : EmergencyContact(
                    name: _emergencyNameController.text.trim().isEmpty
                        ? null
                        : _emergencyNameController.text.trim(),
                    phone: _emergencyPhoneController.text.trim().isEmpty
                        ? null
                        : _emergencyPhoneController.text.trim(),
                  ).toMap(),
            'location': _addressKey.currentState!.value?.toMap(),
          },
        ),
        loadingMessage: 'Saving…',
        successMessage: 'Profile saved.',
      );
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CliniqnovvaTextField(label: 'Full name', controller: _nameController),
          const SizedBox(height: 16),
          CliniqnovvaTextField(
            label: 'Phone',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PatientDateField(
                  label: 'Date of birth',
                  date: _dob,
                  onTap: _pickDob,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GenderDropdown(
                  value: _gender,
                  onChanged: (value) => setState(() => _gender = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CliniqnovvaTextField(
            label: 'National ID',
            controller: _nationalIdController,
            hint: '16 digits',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Emergency contact name',
                  controller: _emergencyNameController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Emergency contact phone',
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Address',
            style: TextStyle(
              color: context.appText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          PatientAddressForm(key: _addressKey, initial: widget.patient.location),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.pillRedBg,
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.pillRedText,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: 160,
            child: CliniqnovvaButton(
              label: 'Save changes',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// Part 9 Task 3 — role-gated at render time by what actually came back:
/// [PatientModel.medicalRecords] is null for a receptionist because the API
/// never sent it, not because this widget filtered it out.
class _MedicalRecordsTab extends StatelessWidget {
  const _MedicalRecordsTab({required this.patient, required this.role});

  final PatientModel patient;
  final String role;

  @override
  Widget build(BuildContext context) {
    final records = patient.medicalRecords;
    if (records == null) {
      return _RestrictedNotice(
        message: 'Medical records aren\'t available for your role.',
      );
    }

    final canWrite =
        role == AppConstants.roleDoctor || role == AppConstants.roleNurse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canWrite) ...[
          _AddRecordForm(patientId: patient.id, role: role),
          const SizedBox(height: 24),
        ],
        Text(
          'Visit history',
          style: TextStyle(
            color: context.appText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          Text(
            'No visits recorded yet.',
            style: TextStyle(color: context.appSubtext),
          )
        else
          ...records.map((r) => _RecordCard(record: r)),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final MedicalRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: context.cardDeco(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.createdAt != null
                ? _formatDateTime(record.createdAt!)
                : 'Unknown date',
            style: TextStyle(color: context.appSubtext, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          if (record.diagnosis != null && record.diagnosis!.isNotEmpty) ...[
            _Field(label: 'Diagnosis', value: record.diagnosis!),
            const SizedBox(height: 8),
          ],
          if (record.prescriptions.isNotEmpty) ...[
            Text(
              'Prescriptions',
              style: TextStyle(
                color: context.appSubtext,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final p in record.prescriptions)
              Text(
                '${p.medicineName}${p.dosage != null ? ' — ${p.dosage}' : ''}${p.duration != null ? ' (${p.duration})' : ''}',
                style: TextStyle(color: context.appText, fontSize: 13.5),
              ),
            const SizedBox(height: 8),
          ],
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            _Field(label: 'Notes', value: record.notes!),
            const SizedBox(height: 8),
          ],
          if (record.vitals != null && record.vitals!.values.isNotEmpty) ...[
            Text(
              'Vitals',
              style: TextStyle(
                color: context.appSubtext,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: record.vitals!.values.entries
                  .map(
                    (e) => Text(
                      '${e.key}: ${e.value}',
                      style: TextStyle(color: context.appText, fontSize: 13.5),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appSubtext,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: context.appText, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _AddRecordForm extends ConsumerStatefulWidget {
  const _AddRecordForm({required this.patientId, required this.role});

  final String patientId;
  final String role;

  @override
  ConsumerState<_AddRecordForm> createState() => _AddRecordFormState();
}

class _AddRecordFormState extends ConsumerState<_AddRecordForm> {
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _medicineController = TextEditingController();
  final _dosageController = TextEditingController();
  final _durationController = TextEditingController();
  final _bpController = TextEditingController();
  final _tempController = TextEditingController();
  final _pulseController = TextEditingController();
  final _weightController = TextEditingController();

  final List<Prescription> _prescriptions = [];
  bool _saving = false;
  String? _error;

  bool get _isDoctor => widget.role == AppConstants.roleDoctor;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _medicineController.dispose();
    _dosageController.dispose();
    _durationController.dispose();
    _bpController.dispose();
    _tempController.dispose();
    _pulseController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _addPrescription() {
    final medicine = _medicineController.text.trim();
    if (medicine.isEmpty) return;
    setState(() {
      _prescriptions.add(
        Prescription(
          medicineName: medicine,
          dosage: _dosageController.text.trim().isEmpty
              ? null
              : _dosageController.text.trim(),
          duration: _durationController.text.trim().isEmpty
              ? null
              : _durationController.text.trim(),
        ),
      );
      _medicineController.clear();
      _dosageController.clear();
      _durationController.clear();
    });
  }

  Map<String, String> _collectVitals() {
    final vitals = <String, String>{};
    if (_bpController.text.trim().isNotEmpty) {
      vitals['Blood pressure'] = _bpController.text.trim();
    }
    if (_tempController.text.trim().isNotEmpty) {
      vitals['Temperature (°C)'] = _tempController.text.trim();
    }
    if (_pulseController.text.trim().isNotEmpty) {
      vitals['Pulse (bpm)'] = _pulseController.text.trim();
    }
    if (_weightController.text.trim().isNotEmpty) {
      vitals['Weight (kg)'] = _weightController.text.trim();
    }
    return vitals;
  }

  Future<void> _save() async {
    final vitals = _collectVitals();
    final diagnosis = _diagnosisController.text.trim();
    final notes = _notesController.text.trim();

    if (_isDoctor && diagnosis.isEmpty && vitals.isEmpty) {
      setState(() => _error = 'Add a diagnosis or at least one vital.');
      return;
    }
    if (!_isDoctor && vitals.isEmpty) {
      setState(() => _error = 'Add at least one vital.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // Offline-first (2026-07-30) — checked before calling so the loading/
    // success messages can reflect what's actually about to happen; the
    // notifier itself branches the same way internally to decide whether
    // to enqueue or send.
    final isOffline = ref.read(isOfflineProvider).valueOrNull ?? false;

    try {
      await runWithFeedback(
        context,
        () => ref.read(patientsNotifierProvider.notifier).addMedicalRecord(
          widget.patientId,
          diagnosis: _isDoctor && diagnosis.isNotEmpty ? diagnosis : null,
          prescriptions: _isDoctor ? _prescriptions : null,
          notes: _isDoctor && notes.isNotEmpty ? notes : null,
          vitals: vitals.isEmpty ? null : vitals,
        ),
        loadingMessage: isOffline ? 'Saving locally…' : 'Saving visit…',
        successMessage: isOffline
            ? 'Saved locally — will sync once you\'re back online.'
            : 'Visit recorded.',
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _diagnosisController.clear();
        _notesController.clear();
        _bpController.clear();
        _tempController.clear();
        _pulseController.clear();
        _weightController.clear();
        _prescriptions.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isDoctor ? 'Record a visit' : 'Record vitals',
            style: TextStyle(
              color: context.appText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (_isDoctor) ...[
            CliniqnovvaTextField(
              label: 'Diagnosis',
              controller: _diagnosisController,
            ),
            const SizedBox(height: 14),
            Text(
              'Prescriptions',
              style: TextStyle(
                color: context.appText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: CliniqnovvaTextField(
                    label: 'Medicine',
                    controller: _medicineController,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CliniqnovvaTextField(
                    label: 'Dosage',
                    controller: _dosageController,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CliniqnovvaTextField(
                    label: 'Duration',
                    controller: _durationController,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const AppIcon(AppIcons.plus),
                  onPressed: _addPrescription,
                ),
              ],
            ),
            if (_prescriptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < _prescriptions.length; i++)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_prescriptions[i].medicineName}'
                        '${_prescriptions[i].dosage != null ? ' — ${_prescriptions[i].dosage}' : ''}'
                        '${_prescriptions[i].duration != null ? ' (${_prescriptions[i].duration})' : ''}',
                        style: TextStyle(color: context.appText, fontSize: 13.5),
                      ),
                    ),
                    IconButton(
                      icon: AppIcon(
                        AppIcons.trash,
                        size: 15,
                        color: context.appSubtext,
                      ),
                      onPressed: () =>
                          setState(() => _prescriptions.removeAt(i)),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 14),
            CliniqnovvaTextField(label: 'Notes', controller: _notesController),
            const SizedBox(height: 14),
          ],
          Text(
            'Vitals',
            style: TextStyle(
              color: context.appText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Blood pressure',
                  controller: _bpController,
                  hint: 'e.g. 120/80',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Temp (°C)',
                  controller: _tempController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Pulse (bpm)',
                  controller: _pulseController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Weight (kg)',
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.pillRedBg,
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.pillRedText,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: CliniqnovvaButton(
              label: 'Save',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsTab extends ConsumerStatefulWidget {
  const _DocumentsTab({required this.patient, required this.role});

  final PatientModel patient;
  final String role;

  @override
  ConsumerState<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<_DocumentsTab> {
  bool _uploading = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      await runWithFeedback(
        context,
        () => ref.read(patientsNotifierProvider.notifier).uploadDocument(
          widget.patient.id,
          bytes: file!.bytes!,
          filename: file.name,
          contentType: _guessContentType(file.extension),
        ),
        loadingMessage: 'Uploading…',
        successMessage: 'Document uploaded.',
      );
      if (!mounted) return;
      setState(() => _uploading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = '$e';
      });
    }
  }

  static String _guessContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _view(PatientDocumentModel doc) async {
    try {
      final url = await ref
          .read(patientsNotifierProvider.notifier)
          .getDocumentSignedUrl(widget.patient.id, doc.key);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = widget.patient.documents;
    if (documents == null) {
      return _RestrictedNotice(
        message: 'Documents aren\'t available for your role.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lab results, X-rays, scans',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: CliniqnovvaButton(
                label: '+ Upload',
                isLoading: _uploading,
                onPressed: _uploading ? null : _pickAndUpload,
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pillRedBg,
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.pillRedText, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (documents.isEmpty)
          Text(
            'No documents uploaded yet.',
            style: TextStyle(color: context.appSubtext),
          )
        else
          for (final doc in documents) _DocumentRow(doc: doc, onView: () => _view(doc)),
      ],
    );
  }
}

class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({required this.doc, required this.onView});

  final PatientDocumentModel doc;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: context.cardDeco(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.originalName,
                  style: TextStyle(
                    color: context.appText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (doc.uploadedAt != null)
                      _formatDateTime(doc.uploadedAt!),
                    if (doc.uploadedBy != null) 'by ${doc.uploadedBy}',
                  ].join(' · '),
                  style: TextStyle(color: context.appSubtext, fontSize: 12),
                ),
              ],
            ),
          ),
          CliniqnovvaButton.text(
            label: 'View',
            color: context.appText,
            onPressed: onView,
          ),
        ],
      ),
    );
  }
}

class _RestrictedNotice extends StatelessWidget {
  const _RestrictedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Text(message, style: TextStyle(color: context.appSubtext)),
    );
  }
}
