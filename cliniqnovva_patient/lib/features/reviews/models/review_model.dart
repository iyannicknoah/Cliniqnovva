/// Mirrors the backend's `reviews` document exactly (Part 16/24) — one
/// review per completed appointment, covering both the branch and the
/// assigned doctor. `patientId` here is the caller's own resolved
/// /patients record id (server-derived on create, see reviews.service.js's
/// Part 24 ownership fix), never the account's own uid.
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.patientId,
    required this.clinicId,
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
  });

  final String id;
  final String patientId;
  final String clinicId;
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

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'] as String,
    patientId: json['patientId'] as String? ?? '',
    clinicId: json['clinicId'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    doctorId: json['doctorId'] as String? ?? '',
    appointmentId: json['appointmentId'] as String? ?? '',
    branchRating: (json['branchRating'] as num?)?.toInt() ?? 0,
    branchComment: json['branchComment'] as String?,
    doctorRating: (json['doctorRating'] as num?)?.toInt() ?? 0,
    doctorComment: json['doctorComment'] as String?,
    isHidden: json['isHidden'] as bool? ?? false,
    hiddenReason: json['hiddenReason'] as String?,
    staffReply: json['staffReply'] is Map<String, dynamic> ? StaffReply.fromJson(json['staffReply'] as Map<String, dynamic>) : null,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
  );

  /// UI-only check (Part 24 Task 2: "check createdAt against the window
  /// client-side for UI state, but the backend is the real enforcement" —
  /// `reviews.service.js`'s `EDIT_WINDOW_MS`, always measured from
  /// `createdAt`, never reset by a prior edit). A disabled button here is
  /// not the security boundary — the server re-checks this on every
  /// update()/remove() call regardless of what the client thinks.
  bool get isWithinEditWindow {
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt!) <= const Duration(hours: 48);
  }
}

class StaffReply {
  const StaffReply({required this.text, this.repliedAt});

  final String text;
  final DateTime? repliedAt;

  factory StaffReply.fromJson(Map<String, dynamic> json) => StaffReply(
    text: json['text'] as String? ?? '',
    repliedAt: json['repliedAt'] != null ? DateTime.tryParse(json['repliedAt'] as String) : null,
  );
}
