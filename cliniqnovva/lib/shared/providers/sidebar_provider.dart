import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sidebar collapsed/expanded state (2026-08-14, explicit user instruction —
/// "navbar that expands and de-expands"). Lives in a provider rather than
/// local widget state because `CliniqnovvaSidebar` is rebuilt fresh by every
/// screen's own shell (`AppShell`/`SuperAdminScaffold`) on each navigation —
/// local state would forget the collapsed choice on every route change.
/// Defaults to collapsed (`true`) — 2026-08-14, explicit user instruction
/// ("by default the navbar to start collapsed"), was expanded (`false`).
final sidebarCollapsedProvider = StateProvider<bool>((ref) => true);
