import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../staff/providers/staff_provider.dart';
import '../models/audit_log_model.dart';
import '../providers/audit_log_provider.dart';

/// Restored 2026-07-29 (docs/technical-spec.md §6.12) — view-only table of
/// every audited action (clinic suspend/billing/payment, staff create/
/// deactivate, invoice payment/void, patient merge, Support View start/end).
/// Reused as-is by both the Clinic Admin route (`/audit-log`, inside the
/// general `ShellRoute` — this widget builds its own `Scaffold`, same
/// pattern as every other `ShellRoute` screen) and the Super Admin route
/// (`/super-admin/audit-log`, wrapped in `SuperAdminScaffold` instead — see
/// `SuperAdminAuditLogScreen` below).
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: const Padding(padding: EdgeInsets.all(40), child: AuditLogBody()),
    );
  }
}

class AuditLogBody extends ConsumerStatefulWidget {
  const AuditLogBody({super.key, this.showTitle = true});

  /// False for the Super Admin route (2026-07-30, bug fix) — `SuperAdminScaffold`
  /// already renders "Audit Log" in its own topbar via its `title` param,
  /// so this widget's own heading would otherwise show twice on that route.
  /// The Clinic Admin route has no such topbar title, so it keeps this
  /// heading (default true), same as every other `ShellRoute` screen
  /// rendering its own page title.
  final bool showTitle;

  @override
  ConsumerState<AuditLogBody> createState() => AuditLogBodyState();
}

class AuditLogBodyState extends ConsumerState<AuditLogBody> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Text(
            'Audit Log',
            style: TextStyle(
              color: context.appText,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: 320,
          child: CliniqnovvaTextField(
            label: 'Filter by action',
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: logsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => Center(
              child: Text('$e', style: TextStyle(color: context.appSubtext)),
            ),
            data: (logs) {
              final filtered = _search.isEmpty
                  ? logs
                  : logs
                        .where((l) => l.action.toLowerCase().contains(_search))
                        .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CliniqnovvaTableHeader(
                    columns: ['When', 'Actor', 'Action', 'Target'],
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No audit entries yet.',
                              style: TextStyle(color: context.appSubtext),
                            ),
                          )
                        : ListView(
                            children: filtered
                                .map((log) => _AuditLogRow(log: log))
                                .toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.log});

  final AuditLogModel log;

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaTableRow(
      cells: [
        Text(
          _formatDateTime(log.timestamp),
          style: TextStyle(color: context.appSubtext, fontSize: 12.5),
        ),
        _ActorCell(actorId: log.actorId, actorRole: log.actorRole),
        Text(log.action, style: TextStyle(color: context.appText)),
        Text(
          '${log.targetCollection}${log.targetId != null ? ' · ${log.targetId}' : ''}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.appSubtext),
        ),
      ],
    );
  }
}

/// Resolves [actorId] to a display name via the existing staff lookup —
/// same "id -> looked-up display value, '—' on error/loading" pattern as
/// inventory_screen.dart's `_ItemNameCell`. Falls back to the raw
/// [actorRole] label if the lookup fails (e.g. a Clinic Admin actor, whose
/// account isn't in the Staff collection at all).
class _ActorCell extends ConsumerWidget {
  const _ActorCell({required this.actorId, required this.actorRole});

  final String? actorId;
  final String? actorRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (actorId == null) {
      return Text('—', style: TextStyle(color: context.appSubtext));
    }
    final staffAsync = ref.watch(staffDetailProvider(actorId!));
    return staffAsync.when(
      loading: () => Text(
        actorRole ?? '—',
        style: TextStyle(color: context.appSubtext),
      ),
      error: (e, _) => Text(
        actorRole ?? '—',
        style: TextStyle(color: context.appSubtext),
      ),
      data: (staff) => Text(
        staff.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
      ),
    );
  }
}

String _formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final local = d.toLocal();
  final date =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
