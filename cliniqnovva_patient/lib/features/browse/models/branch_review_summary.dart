/// Mirrors browse.service.js's `listBranchReviews()` shape exactly — the
/// patient-safe, isHidden-excluded projection (id/branchRating/
/// branchComment/staffReply/createdAt only, no patientId).
class BranchReviewSummary {
  const BranchReviewSummary({
    required this.id,
    required this.branchRating,
    this.branchComment,
    this.staffReply,
    required this.createdAt,
  });

  factory BranchReviewSummary.fromJson(Map<String, dynamic> json) {
    return BranchReviewSummary(
      id: json['id'] as String,
      branchRating: (json['branchRating'] as num?)?.toInt() ?? 0,
      branchComment: json['branchComment'] as String?,
      staffReply: json['staffReply'] == null
          ? null
          : StaffReply.fromJson(json['staffReply'] as Map<String, dynamic>),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final int branchRating;
  final String? branchComment;
  final StaffReply? staffReply;
  final DateTime createdAt;
}

class StaffReply {
  const StaffReply({required this.text, this.repliedAt});

  factory StaffReply.fromJson(Map<String, dynamic> json) {
    return StaffReply(
      text: json['text'] as String? ?? '',
      repliedAt: DateTime.tryParse(json['repliedAt'] as String? ?? ''),
    );
  }

  final String text;
  final DateTime? repliedAt;
}
