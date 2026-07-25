import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/review_model.dart';

/// Staff browsing (Part 16 Task 3) — every review at the branch, including
/// hidden ones (a moderator needs to see what they hid). Null [branchId]
/// lets the server infer scope, same convention as every other list
/// provider in this app.
final reviewsListProvider = FutureProvider.autoDispose
    .family<List<ReviewModel>, String?>((ref, branchId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/reviews',
        queryParameters: branchId != null ? {'branchId': branchId} : null,
      );
      final data = response.data!['reviews'] as List<dynamic>;
      return data
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Part 17 Task 4 — the sidebar's Reviews badge count: visible reviews with
/// no staff reply yet. Derived from [reviewsListProvider] rather than a
/// separate endpoint — one review list, one source of truth.
final reviewsNeedingReplyCountProvider = FutureProvider.autoDispose
    .family<int, String?>((ref, branchId) async {
      final reviews = await ref.watch(reviewsListProvider(branchId).future);
      return reviews.where((r) => !r.isHidden && r.staffReply == null).length;
    });

/// Part 16 Task 5 — one branch's own popularityScore + rank among its
/// clinic's branches.
final popularityRankProvider = FutureProvider.autoDispose
    .family<PopularityRank, String?>((ref, branchId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/reviews/popularity-rank',
        queryParameters: branchId != null ? {'branchId': branchId} : null,
      );
      return PopularityRank.fromJson(response.data!);
    });

/// Owns every staff-side review write action (Part 16) — screens call
/// these instead of hitting ApiService directly. There is no create/update
/// here at all: only the review's own patient author can write those
/// fields, and there's no Patient App yet to call them from (see
/// reviews.routes.js's docstring) — staff can only reply and hide.
class ReviewsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> reply(String reviewId, String text) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/reviews/$reviewId/reply',
      data: {'text': text},
    );
    ref.invalidate(reviewsListProvider);
  }

  /// Org Admin/Super Admin only (server-enforced) — [hidden] false unhides.
  Future<void> setHidden(String reviewId, bool hidden, {String? reason}) async {
    await ApiService.instance.patch<Map<String, dynamic>>(
      '/api/v1/reviews/$reviewId/hide',
      data: {'hidden': hidden, 'reason': reason},
    );
    ref.invalidate(reviewsListProvider);
  }
}

final reviewsNotifierProvider = AsyncNotifierProvider<ReviewsNotifier, void>(
  ReviewsNotifier.new,
);
