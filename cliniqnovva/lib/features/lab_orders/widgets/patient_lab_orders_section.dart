import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/lab_order_model.dart';
import '../providers/lab_orders_provider.dart';

BadgeType _badgeFor(String status) => switch (status) {
  'ordered' => BadgeType.warning,
  'collected' => BadgeType.info,
  'resulted' => BadgeType.info,
  'reviewed' => BadgeType.success,
  _ => BadgeType.info,
};

String _statusLabel(String status) => switch (status) {
  'ordered' => 'Awaiting collection',
  'collected' => 'Awaiting result',
  'resulted' => 'Awaiting review',
  'reviewed' => 'Reviewed',
  _ => status,
};

/// Lab-order history + actions for one patient, embedded in the Patient
/// Profile panel's (`patient_profile_screen.dart`) "Lab Orders" tab. A
/// Doctor sees an "Order a test" form and the review action on resulted
/// orders; Nurse/Laboratorian
/// see collect/record-result actions (same dual-capability decision as
/// addMedicalRecord's Nurse-only vitals tier, just extended to a second
/// role here) — matches the confirmed clinical flow: Doctor orders ->
/// Nurse/Laboratorian performs -> Doctor reviews.
class PatientLabOrdersSection extends ConsumerWidget {
  const PatientLabOrdersSection({
    super.key,
    required this.patientId,
    required this.branchId,
    required this.role,
  });

  final String patientId;
  final String branchId;
  final String role;

  bool get _isDoctor => role == AppConstants.roleDoctor;
  bool get _canPerform =>
      role == AppConstants.roleNurse || role == AppConstants.roleLaboratorian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (branchId: branchId, status: null, patientId: patientId);
    final ordersAsync = ref.watch(labOrdersListProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isDoctor) ...[
          _OrderTestForm(patientId: patientId, branchId: branchId, query: query),
          const SizedBox(height: 24),
        ],
        Text(
          'Lab orders',
          style: TextStyle(
            color: context.appText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ordersAsync.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
          data: (orders) {
            if (orders.isEmpty) {
              return Text(
                'No lab tests ordered yet.',
                style: TextStyle(color: context.appSubtext),
              );
            }
            return Column(
              children: orders
                  .map(
                    (o) => _LabOrderCard(
                      order: o,
                      canPerform: _canPerform,
                      isDoctor: _isDoctor,
                      query: query,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _OrderTestForm extends ConsumerStatefulWidget {
  const _OrderTestForm({
    required this.patientId,
    required this.branchId,
    required this.query,
  });

  final String patientId;
  final String branchId;
  final LabOrdersQuery query;

  @override
  ConsumerState<_OrderTestForm> createState() => _OrderTestFormState();
}

class _OrderTestFormState extends ConsumerState<_OrderTestForm> {
  final _testNameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _testNameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _order() async {
    final testName = _testNameController.text.trim();
    if (testName.isEmpty) {
      setState(() => _error = 'Test name is required.');
      return;
    }
    final price = int.tryParse(_priceController.text.trim()) ?? 0;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await runWithFeedback(
        context,
        () => ref.read(labOrdersNotifierProvider.notifier).order(
          branchId: widget.branchId,
          patientId: widget.patientId,
          testName: testName,
          priceRwf: price,
        ),
        loadingMessage: 'Ordering…',
        successMessage: 'Test ordered.',
      );
      ref.invalidate(labOrdersListProvider(widget.query));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _testNameController.clear();
        _priceController.clear();
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
            'Order a lab test',
            style: TextStyle(
              color: context.appText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: CliniqnovvaTextField(
                  label: 'Test name',
                  controller: _testNameController,
                  hint: 'e.g. Malaria RDT',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Price (RWF)',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.brightRed, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: 140,
            child: CliniqnovvaButton(
              label: 'Order test',
              isLoading: _saving,
              onPressed: _saving ? null : _order,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabOrderCard extends ConsumerStatefulWidget {
  const _LabOrderCard({
    required this.order,
    required this.canPerform,
    required this.isDoctor,
    required this.query,
  });

  final LabOrderModel order;
  final bool canPerform;
  final bool isDoctor;
  final LabOrdersQuery query;

  @override
  ConsumerState<_LabOrderCard> createState() => _LabOrderCardState();
}

class _LabOrderCardState extends ConsumerState<_LabOrderCard> {
  final _resultController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {required String loading, required String success}) async {
    setState(() => _busy = true);
    try {
      await runWithFeedback(context, action, loadingMessage: loading, successMessage: success);
      ref.invalidate(labOrdersListProvider(widget.query));
    } catch (_) {
      // runWithFeedback already surfaced the error.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: context.cardDeco(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.testName,
                  style: TextStyle(color: context.appText, fontWeight: FontWeight.w600),
                ),
              ),
              StatusBadge(text: _statusLabel(order.status), type: _badgeFor(order.status)),
            ],
          ),
          if (order.resultValue != null) ...[
            const SizedBox(height: 8),
            Text(
              'Result: ${order.resultValue}${order.resultUnit != null ? ' ${order.resultUnit}' : ''}',
              style: TextStyle(color: context.appText, fontSize: 13.5),
            ),
          ],
          if (widget.canPerform && order.status == 'ordered') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: CliniqnovvaButton(
                label: 'Mark collected',
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref.read(labOrdersNotifierProvider.notifier).markCollected(order.id),
                        loading: 'Saving…',
                        success: 'Marked collected.',
                      ),
              ),
            ),
          ],
          if (widget.canPerform && order.status == 'collected') ...[
            const SizedBox(height: 12),
            CliniqnovvaTextField(label: 'Result', controller: _resultController),
            const SizedBox(height: 10),
            SizedBox(
              width: 160,
              child: CliniqnovvaButton(
                label: 'Record result',
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : () {
                        final value = _resultController.text.trim();
                        if (value.isEmpty) return;
                        _run(
                          () => ref.read(labOrdersNotifierProvider.notifier).recordResult(order.id, resultValue: value),
                          loading: 'Saving…',
                          success: 'Result recorded.',
                        );
                      },
              ),
            ),
          ],
          if (widget.isDoctor && order.status == 'resulted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              child: CliniqnovvaButton(
                label: 'Mark reviewed',
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref.read(labOrdersNotifierProvider.notifier).markReviewed(order.id),
                        loading: 'Saving…',
                        success: 'Marked reviewed.',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
