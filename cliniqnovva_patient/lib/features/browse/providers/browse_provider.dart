import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../models/branch_review_summary.dart';
import '../models/branch_summary.dart';
import '../models/doctor_summary.dart';
import '../models/service_summary.dart';

/// Browse screen's search/sort/department state — deliberately a plain
/// value type (not a free-floating set of provider args) so
/// [branchListProvider]'s family key is stable and easy to reason about.
class BrowseFilters {
  const BrowseFilters({this.search = '', this.sortBy = 'popular', this.department});

  final String search;
  final String sortBy;
  final String? department;

  BrowseFilters copyWith({String? search, String? sortBy, String? department, bool clearDepartment = false}) {
    return BrowseFilters(
      search: search ?? this.search,
      sortBy: sortBy ?? this.sortBy,
      department: clearDepartment ? null : (department ?? this.department),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BrowseFilters && other.search == search && other.sortBy == sortBy && other.department == department;

  @override
  int get hashCode => Object.hash(search, sortBy, department);
}

class BranchListResult {
  const BranchListResult({
    required this.branches,
    required this.availableDepartments,
    required this.departmentCounts,
    required this.reviewCountThreshold,
  });

  final List<BranchSummary> branches;
  final List<String> availableDepartments;

  /// Service name -> how many public branches offer it. Used only by
  /// [homeBrowseProvider] for the Home screen's service cards — Browse's
  /// own filter chips still just use [availableDepartments].
  final Map<String, int> departmentCounts;
  final int reviewCountThreshold;
}

/// GET /api/v1/browse/branches — Browse screen's search/filter/sort list
/// (Part 20 Task 2) and, unfiltered, the Home screen's source data (Task 1).
final branchListProvider = FutureProvider.autoDispose.family<BranchListResult, BrowseFilters>((ref, filters) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/browse/branches',
    queryParameters: {
      if (filters.search.trim().isNotEmpty) 'search': filters.search.trim(),
      'sortBy': filters.sortBy,
      if (filters.department != null) 'department': filters.department,
    },
  );
  final data = response.data!;
  return BranchListResult(
    branches: (data['branches'] as List).map((e) => BranchSummary.fromJson(e as Map<String, dynamic>)).toList(),
    availableDepartments: (data['availableDepartments'] as List).map((e) => e.toString()).toList(),
    departmentCounts: (data['departmentCounts'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    ),
    reviewCountThreshold: (data['reviewCountThreshold'] as num?)?.toInt() ?? 5,
  );
});

class HomeBrowseData {
  const HomeBrowseData({required this.popular, required this.newOnes, required this.services});

  final List<BranchSummary> popular;
  final List<BranchSummary> newOnes;

  /// Every distinct service offered across all public branches, each with
  /// its clinic count — already deduped/counted server-side
  /// (browse.service.js#distinctDepartments/#departmentCounts), not
  /// recomputed here. Backs the Home screen's service cards.
  final List<ServiceSummary> services;
}

/// Home screen's service cards + "Popular Clinics"/"New on Clisante"
/// sections (Task 1) — one unfiltered fetch, split client-side on the
/// server-provided reviewCountThreshold (reviews.service.js's
/// REVIEW_COUNT_THRESHOLD).
final homeBrowseProvider = FutureProvider.autoDispose<HomeBrowseData>((ref) async {
  final result = await ref.watch(branchListProvider(const BrowseFilters()).future);
  return HomeBrowseData(
    popular: result.branches.where((b) => b.reviewCount >= result.reviewCountThreshold).toList(),
    newOnes: result.branches.where((b) => b.reviewCount < result.reviewCountThreshold).toList(),
    services: result.availableDepartments
        .map((name) => ServiceSummary(name: name, clinicCount: result.departmentCounts[name] ?? 0))
        .toList(),
  );
});

/// Every distinct service across every public branch, alphabetically —
/// backs `ExploreServicesScreen` (Home's service "View all"), as opposed
/// to [homeBrowseProvider]'s top-3-by-count subset. Deliberately a
/// separate provider rather than reusing `homeBrowseProvider` — this
/// needs the FULL list, unfiltered/untrimmed, and sorted for scanning
/// rather than by popularity.
final allServicesProvider = FutureProvider.autoDispose<List<ServiceSummary>>((ref) async {
  final result = await ref.watch(branchListProvider(const BrowseFilters()).future);
  final services = result.availableDepartments
      .map((name) => ServiceSummary(name: name, clinicCount: result.departmentCounts[name] ?? 0))
      .toList();
  services.sort((a, b) => a.name.compareTo(b.name));
  return services;
});

class BranchDetailResult {
  const BranchDetailResult({required this.branch, required this.doctors});

  final BranchSummary branch;
  final List<DoctorSummary> doctors;
}

/// GET /api/v1/browse/branches/:branchId — Clinic Detail screen (Task 3).
final branchDetailProvider = FutureProvider.autoDispose.family<BranchDetailResult, String>((ref, branchId) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/browse/branches/$branchId');
  final data = response.data!;
  return BranchDetailResult(
    branch: BranchSummary.fromJson(data['branch'] as Map<String, dynamic>),
    doctors: (data['doctors'] as List).map((e) => DoctorSummary.fromJson(e as Map<String, dynamic>)).toList(),
  );
});

/// GET /api/v1/doctors/:id — Doctor Detail screen (Task 3).
final doctorDetailProvider = FutureProvider.autoDispose.family<DoctorSummary, String>((ref, doctorId) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/doctors/$doctorId');
  return DoctorSummary.fromJson(response.data!['doctor'] as Map<String, dynamic>);
});

class BranchReviewsState {
  const BranchReviewsState({required this.reviews, required this.hasMore, this.isLoadingMore = false});

  final List<BranchReviewSummary> reviews;
  final bool hasMore;
  final bool isLoadingMore;

  BranchReviewsState copyWith({List<BranchReviewSummary>? reviews, bool? hasMore, bool? isLoadingMore}) {
    return BranchReviewsState(
      reviews: reviews ?? this.reviews,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// GET /api/v1/browse/branches/:branchId/reviews, page by page (Task 3:
/// "paginated"). One instance per branchId (family), holds every page
/// fetched so far; [loadMore] appends the next one.
class BranchReviewsNotifier extends StateNotifier<AsyncValue<BranchReviewsState>> {
  BranchReviewsNotifier(this.branchId) : super(const AsyncValue.loading()) {
    _loadFirstPage();
  }

  static const pageSize = 10;

  final String branchId;

  Future<BranchReviewsState> _fetchPage(int offset) async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/api/v1/browse/branches/$branchId/reviews',
      queryParameters: {'limit': pageSize, 'offset': offset},
    );
    final data = response.data!;
    final page = (data['reviews'] as List)
        .map((e) => BranchReviewSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    return BranchReviewsState(reviews: page, hasMore: data['hasMore'] as bool? ?? false);
  }

  Future<void> _loadFirstPage() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPage(0));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    final next = await _fetchPage(current.reviews.length);
    state = AsyncValue.data(
      current.copyWith(reviews: [...current.reviews, ...next.reviews], hasMore: next.hasMore, isLoadingMore: false),
    );
  }
}

final branchReviewsProvider =
    StateNotifierProvider.autoDispose.family<BranchReviewsNotifier, AsyncValue<BranchReviewsState>, String>(
  (ref, branchId) => BranchReviewsNotifier(branchId),
);

/// Optional device location (Task 1: "distance if location permission
/// granted") — null on denial/unavailable, never throws, never blocks Browse.
final userLocationProvider = FutureProvider.autoDispose<Position?>((ref) {
  return LocationService.getCurrentPositionIfPermitted();
});
