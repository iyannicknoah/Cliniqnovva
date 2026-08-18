import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sidebar collapsed/expanded state (2026-08-14, explicit user instruction —
/// "navbar that expands and de-expands"). Lives in a provider rather than
/// local widget state because `CliniqnovvaSidebar` is rebuilt fresh by every
/// screen's own shell (`AppShell`/`SuperAdminScaffold`) on each navigation —
/// local state would forget the collapsed choice on every route change.
/// Defaults to expanded (`false`) — 2026-08-19, explicit user instruction
/// ("navbar by default to start Expanded"), reverting the 2026-08-14 default
/// of collapsed (`true`).
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
