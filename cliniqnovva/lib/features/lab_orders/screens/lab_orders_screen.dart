import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../patients/providers/patients_provider.dart';
import '../models/lab_order_model.dart';
import '../providers/lab_orders_provider.dart';

/// Nurse/Laboratorian worklist (2026-07-29) — every lab order for this
/// branch needing action, split into "Pending Collection" (ordered) and
/// "Awaiting Result" (collected) tabs. Same collect/record-result actions
/// as `PatientLabOrdersSection`, just across the whole branch instead of
/// one patient — a specimen-runner working the queue doesn't want to open
/// each patient's profile individually to find what's next.
class LabOrdersScreen extends ConsumerStatefulWidget {
  const LabOrdersScreen({super.key});

  @override
  ConsumerState<LabOrdersScreen> createState() => _LabOrdersScreenState();
}

class _LabOrdersScreenState extends ConsumerState<LabOrdersScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          final ownBranchId = data?['branchId'] as String?;
          final branchId = ownBranchId ?? ref.watch(activeBranchIdProvider);
          if (branchId == null) {
            return Center(
              child: Text('empty_no_branch'.tr(), style: TextStyle(color: context.appSubtext)),
            );
          }

          final status = _tab == 0 ? 'ordered' : 'collected';
          final query = (branchId: branchId, status: status, patientId: null);
          final ordersAsync = ref.watch(labOrdersListProvider(query));

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lab Orders',
                        style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const TopBarActions(),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 340,
                  child: SegmentedTabs(
                    labels: const ['Pending Collection', 'Awaiting Result'],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ordersAsync.when(
                    loading: () => const LoadingWidget(),
                    error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
                    data: (orders) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CliniqnovvaTableHeader(
                          columns: ['Patient', 'Test', 'Ordered', 'Status', 'Action'],
                          lastColumnEndPadding: 50,
                        ),
                        Expanded(
                          child: orders.isEmpty
                              ? Center(
                                  child: Text('Nothing here.', style: TextStyle(color: context.appSubtext)),
                                )
                              : ListView(
                                  children: orders
                                      .map((o) => _WorklistRow(order: o, query: query))
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PatientNameCell extends ConsumerWidget {
  const _PatientNameCell({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    return patientAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('—', style: TextStyle(color: context.appSubtext)),
      data: (patient) => Text(
        patient.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _WorklistRow extends ConsumerStatefulWidget {
  const _WorklistRow({required this.order, required this.query});

  final LabOrderModel order;
  final LabOrdersQuery query;

  @override
  ConsumerState<_WorklistRow> createState() => _WorklistRowState();
}

class _WorklistRowState extends ConsumerState<_WorklistRow> {
  final _resultController = TextEditingController();
  bool _busy = false;
  bool _entering = false;

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _markCollected() async {
    setState(() => _busy = true);
    try {
      await runWithFeedback(
        context,
        () => ref.read(labOrdersNotifierProvider.notifier).markCollected(widget.order.id),
        loadingMessage: 'Saving…',
        successMessage: 'Marked collected.',
      );
      ref.invalidate(labOrdersListProvider(widget.query));
    } catch (_) {
      // runWithFeedback already surfaced the error.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordResult() async {
    final value = _resultController.text.trim();
    if (value.isEmpty) return;
    setState(() => _busy = true);
    try {
      await runWithFeedback(
        context,
        () => ref.read(labOrdersNotifierProvider.notifier).recordResult(widget.order.id, resultValue: value),
        loadingMessage: 'Saving…',
        successMessage: 'Result recorded.',
      );
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
    return CliniqnovvaTableRow(
      lastColumnEndPadding: 50,
      onTap: () => context.push('/patients/${order.patientId}'),
      cells: [
        _PatientNameCell(patientId: order.patientId),
        Text(order.testName, style: TextStyle(color: context.appText)),
        Text(
          order.orderedAt != null ? _formatDate(order.orderedAt!) : '—',
          style: TextStyle(color: context.appSubtext, fontSize: 12.5),
        ),
        StatusBadge(
          text: order.status == 'ordered' ? 'Ordered' : 'Collected',
          type: BadgeType.warning,
        ),
        if (order.status == 'ordered')
          SizedBox(
            width: 130,
            child: CliniqnovvaButton(
              label: 'Mark collected',
              isLoading: _busy,
              onPressed: _busy ? null : _markCollected,
            ),
          )
        else if (!_entering)
          SizedBox(
            width: 130,
            child: CliniqnovvaButton(
              label: 'Record result',
              onPressed: () => setState(() => _entering = true),
            ),
          )
        else
          SizedBox(
            width: 220,
            child: Row(
              children: [
                Expanded(
                  child: CliniqnovvaTextField(label: 'Result', controller: _resultController),
                ),
                const SizedBox(width: 6),
                CliniqnovvaButton(label: 'Save', isLoading: _busy, onPressed: _busy ? null : _recordResult),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
