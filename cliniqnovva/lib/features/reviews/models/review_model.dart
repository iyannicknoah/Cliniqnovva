/// Mirrors the backend's `reviews` document exactly (Part 16 Task 1) — one
/// review per completed appointment, covering both the branch and the
/// assigned doctor. [branchRating]/[branchComment]/[doctorRating]/
/// [doctorComment] are the patient's own words; nothing here is ever
/// written by staff except [staffReply] and the hide fields.
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.patientId,
    required this.branchId,
    required this.doctorId,
    required this.appointmentId,
    required this.branchRating,
    this.branchComment,
    required this.doctorRating,
    this.doctorComment,
    this.isHidden = false,
    this.hiddenReason,
    this.staffReply,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String branchId;
  final String doctorId;
  final String appointmentId;
  final int branchRating;
  final String? branchComment;
  final int doctorRating;
  final String? doctorComment;
  final bool isHidden;
  final String? hiddenReason;
  final StaffReply? staffReply;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'] as String,
    patientId: json['patientId'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    doctorId: json['doctorId'] as String? ?? '',
    appointmentId: json['appointmentId'] as String? ?? '',
    branchRating: (json['branchRating'] as num?)?.toInt() ?? 0,
    branchComment: json['branchComment'] as String?,
    doctorRating: (json['doctorRating'] as num?)?.toInt() ?? 0,
    doctorComment: json['doctorComment'] as String?,
    isHidden: json['isHidden'] as bool? ?? false,
    hiddenReason: json['hiddenReason'] as String?,
    staffReply: json['staffReply'] is Map<String, dynamic>
        ? StaffReply.fromJson(json['staffReply'] as Map<String, dynamic>)
        : null,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String)
        : null,
  );
}

class StaffReply {
  const StaffReply({required this.text, this.repliedBy, this.repliedAt});

  final String text;
  final String? repliedBy;
  final DateTime? repliedAt;

  factory StaffReply.fromJson(Map<String, dynamic> json) => StaffReply(
    text: json['text'] as String? ?? '',
    repliedBy: json['repliedBy'] as String?,
    repliedAt: json['repliedAt'] != null
        ? DateTime.tryParse(json['repliedAt'] as String)
        : null,
  );
}

/// GET /api/v1/reviews/popularity-rank response (Part 16 Task 5).
class PopularityRank {
  const PopularityRank({
    required this.branchId,
    required this.popularityScore,
    required this.averageRating,
    required this.reviewCount,
    this.popularityCalculatedAt,
    required this.rank,
    required this.totalBranchesRanked,
  });

  final String branchId;
  final double popularityScore;
  final double averageRating;
  final int reviewCount;
  final DateTime? popularityCalculatedAt;
  final int rank;
  final int totalBranchesRanked;

  factory PopularityRank.fromJson(Map<String, dynamic> json) => PopularityRank(
    branchId: json['branchId'] as String? ?? '',
    popularityScore: (json['popularityScore'] as num?)?.toDouble() ?? 0,
    averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
    reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    popularityCalculatedAt: json['popularityCalculatedAt'] != null
        ? DateTime.tryParse(json['popularityCalculatedAt'] as String)
        : null,
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    totalBranchesRanked: (json['totalBranchesRanked'] as num?)?.toInt() ?? 0,
  );
}
