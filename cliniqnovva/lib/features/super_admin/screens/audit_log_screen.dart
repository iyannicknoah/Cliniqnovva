import 'package:flutter/material.dart';

import '../../audit_log/screens/audit_log_screen.dart' show AuditLogBody;
import '../widgets/super_admin_scaffold.dart';

/// Super Admin's view of the same audit log content as the Clinic Admin
/// route (`AuditLogBody`, shared — see audit_log/screens/audit_log_screen.dart)
/// — wrapped in `SuperAdminScaffold` instead of a bare `Scaffold` since
/// Super Admin never goes through the general `AppShell`/`ShellRoute`.
/// Platform-wide by default (no clinicId filter — see auditLog.service.js's
/// `list()`), same "cross-org oversight" scope as the rest of Super Admin.
class SuperAdminAuditLogScreen extends StatelessWidget {
  const SuperAdminAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SuperAdminScaffold(
      currentRoute: '/super-admin/audit-log',
      title: 'Audit Log',
      // showTitle: false — SuperAdminScaffold's own topbar already shows
      // "Audit Log" via the title param above; without this the heading
      // rendered twice (2026-07-30 bug fix).
      body: AuditLogBody(showTitle: false),
    );
  }
}
