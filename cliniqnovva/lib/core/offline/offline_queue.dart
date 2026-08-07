import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-first write flows (2026-07-30) — deliberately just these three,
/// not every write in the app. Patient registration and vitals recording
/// are pure creates (no conflict risk); appointment check-in is the one
/// status transition worth queuing. Billing/invoicing and every other
/// module stay online-only — queuing money-related writes offline risks
/// double-charges, a worse failure mode than "try again in a moment."
enum OfflineMutationKind { registerPatient, recordVitals, checkInAppointment }

/// One write that happened while offline, waiting to be replayed against
/// the real API once connectivity returns. [payload] is the exact same
/// JSON-safe map shape the relevant notifier method would otherwise send to
/// [ApiService] directly — see offline_sync.dart for how each [kind] maps
/// back onto a real API call.
class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.lastError,
  });

  final String id;
  final OfflineMutationKind kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Set once a replay attempt gets a real (non-network) rejection from the
  /// server — e.g. an appointment already checked in by someone else. A
  /// tagged entry is surfaced for manual resolution instead of being
  /// retried forever on every reconnect.
  final String? lastError;

  PendingMutation copyWith({String? lastError}) => PendingMutation(
    id: id,
    kind: kind,
    payload: payload,
    createdAt: createdAt,
    lastError: lastError ?? this.lastError,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'lastError': lastError,
  };

  factory PendingMutation.fromJson(Map<String, dynamic> json) {
    return PendingMutation(
      id: json['id'] as String,
      kind: OfflineMutationKind.values.byName(json['kind'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastError: json['lastError'] as String?,
    );
  }
}

/// Persists the queue to browser localStorage via `shared_preferences` —
/// already a dependency, used the same direct
/// `SharedPreferences.getInstance()`-per-call way `auth_provider.dart`'s
/// theme-mode persistence already does. A JSON-encoded list of small
/// records is well within localStorage's size limits; this deliberately
/// does NOT cache full read datasets (patient lists, appointment lists) —
/// only the queue of pending writes.
class OfflineQueueService {
  OfflineQueueService._();

  static const _key = 'offline_pending_mutations';

  static Future<List<PendingMutation>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((s) => PendingMutation.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _save(List<PendingMutation> mutations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, mutations.map((m) => jsonEncode(m.toJson())).toList());
  }

  // `1 << 32` looks like a natural "max out a 32-bit range" choice, but on
  // web Dart's bitwise shift truncates to 32 bits (unlike the VM's 64-bit
  // ints), so `1 << 32` silently evaluates to 0 there — Random().nextInt(0)
  // then throws immediately. `1 << 31` is unambiguous on every compilation
  // target and gives far more entropy than a timestamp-suffixed id needs
  // anyway.
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

  static Future<PendingMutation> enqueue(
    OfflineMutationKind kind,
    Map<String, dynamic> payload,
  ) async {
    final mutation = PendingMutation(
      id: _newId(),
      kind: kind,
      payload: payload,
      createdAt: DateTime.now(),
    );
    final all = await list()..add(mutation);
    await _save(all);
    return mutation;
  }

  static Future<void> remove(String id) async {
    final all = await list()..removeWhere((m) => m.id == id);
    await _save(all);
  }

  static Future<void> markFailed(String id, String error) async {
    final all = await list();
    final index = all.indexWhere((m) => m.id == id);
    if (index == -1) return;
    all[index] = all[index].copyWith(lastError: error);
    await _save(all);
  }
}

/// Watchable queue state — drives the pending-sync count chip in
/// [OfflineBanner] and is read by [OfflineSyncNotifier] to know what to
/// replay. Screens/notifiers enqueueing a write call [enqueue] directly
/// rather than hitting [OfflineQueueService] themselves, so the reactive
/// state and the persisted state can never drift apart.
class OfflineQueueNotifier extends AsyncNotifier<List<PendingMutation>> {
  @override
  Future<List<PendingMutation>> build() => OfflineQueueService.list();

  Future<PendingMutation> enqueue(
    OfflineMutationKind kind,
    Map<String, dynamic> payload,
  ) async {
    final mutation = await OfflineQueueService.enqueue(kind, payload);
    state = AsyncData([...(state.valueOrNull ?? []), mutation]);
    return mutation;
  }

  Future<void> remove(String id) async {
    await OfflineQueueService.remove(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((m) => m.id != id).toList(),
    );
  }

  Future<void> markFailed(String id, String error) async {
    await OfflineQueueService.markFailed(id, error);
    state = AsyncData([
      for (final m in state.valueOrNull ?? <PendingMutation>[])
        if (m.id == id) m.copyWith(lastError: error) else m,
    ]);
  }
}

final offlineQueueProvider =
    AsyncNotifierProvider<OfflineQueueNotifier, List<PendingMutation>>(
      OfflineQueueNotifier.new,
    );
