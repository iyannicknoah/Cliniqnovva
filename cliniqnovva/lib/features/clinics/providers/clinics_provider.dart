import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/clinic.dart';

final clinicsListProvider =
    FutureProvider.autoDispose<List<Clinic>>((ref) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/clinics',
      );
      final data = response.data!['clinics'] as List<dynamic>;
      return data
          .map((e) => Clinic.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final clinicDetailProvider = FutureProvider.autoDispose
    .family<Clinic, String>((ref, id) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/clinics/$id',
      );
      return Clinic.fromJson(
        response.data!['clinic'] as Map<String, dynamic>,
      );
    });

/// Part 4 Task 3 — the dedicated payment-history endpoint backing the
/// billing screen's per-clinic panel.
final paymentHistoryProvider = FutureProvider.autoDispose
    .family<List<SubscriptionPayment>, String>((ref, id) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/clinics/$id/payment-history',
      );
      final data = response.data!['paymentHistory'] as List<dynamic>;
      return data
          .map((e) => SubscriptionPayment.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Owns every write action on clinics/branches-on-behalf-of-org (Part 3
/// Tasks 2-3) — screens call these instead of hitting ApiService directly.
class ClinicsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String name,
    required String subscriptionPlan,
    required String adminEmail,
    required String adminPassword,
    String? ownerContactName,
    String? ownerContactPhone,
    int? subscriptionAmountRwf,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/clinics',
      data: {
        'name': name,
        'subscriptionPlan': subscriptionPlan,
        'adminEmail': adminEmail,
        'adminPassword': adminPassword,
        'ownerContactName': ownerContactName,
        'ownerContactPhone': ownerContactPhone,
        'subscriptionAmountRwf': subscriptionAmountRwf,
      },
    );
    ref.invalidate(clinicsListProvider);
  }

  Future<void> updateClinic(
    String id,
    Map<String, dynamic> fields,
  ) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/clinics/$id',
      data: fields,
    );
    ref.invalidate(clinicsListProvider);
    ref.invalidate(clinicDetailProvider(id));
  }

  /// Hard-deletes a clinic with zero branches (server rejects it otherwise —
  /// see clinics.service.js#remove). Suspend (setStatus) stays the way to
  /// disable a clinic that has real usage.
  Future<void> remove(String id) async {
    await ApiService.instance.delete<void>('/api/v1/clinics/$id');
    ref.invalidate(clinicsListProvider);
  }

  Future<void> setStatus(String id, bool isActive) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/clinics/$id/status',
      data: {'isActive': isActive},
    );
    ref.invalidate(clinicsListProvider);
    ref.invalidate(clinicDetailProvider(id));
  }

  /// Super Admin manually flips billing status between notPaid/pending/paid
  /// — recording a payment is only allowed once a clinic is marked 'paid'.
  Future<void> setBillingStatus(String id, String billingStatus) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/clinics/$id/billing-status',
      data: {'billingStatus': billingStatus},
    );
    ref.invalidate(clinicsListProvider);
    ref.invalidate(clinicDetailProvider(id));
  }

  /// Super Admin support-exception path (Part 3 Task 3) — backend logs this
  /// as `branch.createdOnBehalfOfClinic`, distinct from a normal
  /// Clinic Admin branch creation (Part 6).
  Future<void> createBranchOnBehalf(
    String clinicId, {
    required String name,
    String? address,
    String? phone,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/branches',
      data: {
        'clinicId': clinicId,
        'name': name,
        'address': address,
        'phone': phone,
      },
    );
    ref.invalidate(clinicDetailProvider(clinicId));
  }

  /// Part 4 Task 2/3 — cash-only record-keeping, no payment gateway. Appends
  /// to `subscriptionPaymentHistory` and recalculates `nextDueDate` server-side.
  Future<void> recordPayment(
    String clinicId, {
    required int amountRwf,
    DateTime? date,
    String? note,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/clinics/$clinicId/record-payment',
      data: {
        'amountRwf': amountRwf,
        'date': date?.toIso8601String(),
        'note': note,
      },
    );
    ref.invalidate(clinicsListProvider);
    ref.invalidate(clinicDetailProvider(clinicId));
    ref.invalidate(paymentHistoryProvider(clinicId));
  }
}

final clinicsNotifierProvider =
    AsyncNotifierProvider<ClinicsNotifier, void>(
      ClinicsNotifier.new,
    );
