import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/linked_patient_ids_provider.dart';
import '../../../core/services/api_service.dart';
import '../models/review_model.dart';

/// GET /api/v1/patients/:patientId/reviews, once per linked clinic (Part
/// 24 Task 2), merged newest-first — same fan-out shape as My Bookings/
/// Medical Records/Receipts (Parts 22/23).
final myReviewsProvider = FutureProvider.autoDispose<List<ReviewModel>>((ref) async {
  final linkedIds = await ref.watch(linkedPatientIdsProvider.future);
  if (linkedIds.isEmpty) return [];

  final results = await Future.wait(
    linkedIds.map((id) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/patients/$id/reviews');
      return (response.data!['reviews'] as List).map((e) => ReviewModel.fromJson(e as Map<String, dynamic>)).toList();
    }),
  );

  final reviews = results.expand((list) => list).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return reviews;
});

/// POST /api/v1/reviews — the SAME endpoint + validation
/// (completed-appointment/one-per-appointment/48h-window) the spec already
/// built; this notifier only shapes the request (Part 24 Task 1).
class LeaveReviewNotifier extends AutoDisposeAsyncNotifier<ReviewModel?> {
  @override
  ReviewModel? build() => null;

  Future<ReviewModel> submit({
    required String appointmentId,
    required int branchRating,
    String? branchComment,
    required int doctorRating,
    String? doctorComment,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiService.instance.post<Map<String, dynamic>>(
        '/api/v1/reviews',
        data: {
          'appointmentId': appointmentId,
          'branchRating': branchRating,
          'branchComment': branchComment,
          'doctorRating': doctorRating,
          'doctorComment': doctorComment,
        },
      );
      final review = ReviewModel.fromJson(response.data!['review'] as Map<String, dynamic>);
      state = AsyncValue.data(review);
      return review;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final leaveReviewNotifierProvider = AsyncNotifierProvider.autoDispose<LeaveReviewNotifier, ReviewModel?>(
  LeaveReviewNotifier.new,
);

/// PATCH/DELETE /api/v1/reviews/:id and POST /api/v1/reviews/:id/flag —
/// My Reviews' Edit/Delete (Task 2) and Clinic Detail's Report action
/// (Task 3). Every call invalidates [myReviewsProvider] so the list
/// reflects the write immediately.
class ReviewActionsNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  void build() {}

  // Named `edit`, not `update` — `update` collides with
  // AsyncNotifierBase's own built-in state-update method.
  Future<void> edit(
    String id, {
    required int branchRating,
    String? branchComment,
    required int doctorRating,
    String? doctorComment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.instance.patch<Map<String, dynamic>>(
        '/api/v1/reviews/$id',
        data: {
          'branchRating': branchRating,
          'branchComment': branchComment,
          'doctorRating': doctorRating,
          'doctorComment': doctorComment,
        },
      );
      state = const AsyncValue.data(null);
      ref.invalidate(myReviewsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.instance.delete<Map<String, dynamic>>('/api/v1/reviews/$id');
      state = const AsyncValue.data(null);
      ref.invalidate(myReviewsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> flag(String id, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.instance.post<Map<String, dynamic>>('/api/v1/reviews/$id/flag', data: {'reason': reason});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final reviewActionsProvider = AsyncNotifierProvider.autoDispose<ReviewActionsNotifier, void>(
  ReviewActionsNotifier.new,
);
