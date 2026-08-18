import '../../clinics/models/branch_model.dart';

/// Required `payoutDetails` keys per `payoutMethod` — mirrors the backend's
/// own `PAYOUT_DETAIL_FIELDS` (branches.service.js) so the wizard's client
/// side validation never disagrees with what the server will accept.
const payoutDetailFields = {
  'momo': ['phone', 'accountName'],
  'airtel': ['phone', 'accountName'],
  'bank': ['bankName', 'accountNumber', 'accountName'],
};

/// The 5-step "Go Public" wizard's completion state, derived entirely from
/// [BranchModel] fields — no separate "progress" document. A step counts as
/// done once its data has been explicitly saved, even with an empty
/// selection (e.g. `publicServiceIds: []`) — `null` means "never touched",
/// which is what distinguishes "saved nothing on purpose" from "hasn't
/// gotten there yet" for [needsAttention] below.
class GoPublicSteps {
  const GoPublicSteps(this.branch);

  final BranchModel branch;

  bool get infoDone =>
      (branch.publicDisplayName ?? '').isNotEmpty &&
      (branch.publicPhone ?? '').isNotEmpty &&
      (branch.publicEmail ?? '').isNotEmpty &&
      (branch.publicAddress ?? '').isNotEmpty &&
      (branch.publicImageKey ?? '').isNotEmpty;

  bool get servicesDone => branch.publicServiceIds != null;

  bool get doctorsDone => branch.publicDoctorIds != null;

  bool get payoutDone {
    final method = branch.payoutMethod;
    if (method == null) return false;
    final required = payoutDetailFields[method];
    if (required == null) return false;
    final details = branch.payoutDetails ?? const {};
    return required.every((f) => (details[f] ?? '').isNotEmpty);
  }

  bool get isLive => branch.isPublic;

  bool get allStepsDone => infoDone && servicesDone && doctorsDone && payoutDone;

  bool get started => infoDone || servicesDone || doctorsDone || payoutDone || isLive;

  /// Drives the sidebar's amber reminder dot — some progress made, but not
  /// live yet. Explicit user instruction: "when he saves when he comes back
  /// we show badge like warning ... to remind him to finish public setup".
  bool get needsAttention => started && !isLive;

  /// Index (0-4, matching the wizard's own step order) of the first step
  /// not yet done — explicit user instruction: clicking "Go Public" should
  /// land on where the admin left off, not always restart at step 0. Every
  /// step already done (branch already live) lands on the last step, "Go
  /// live", same place "Manage public profile" already implies.
  int get firstIncompleteStepIndex {
    if (!infoDone) return 0;
    if (!servicesDone) return 1;
    if (!doctorsDone) return 2;
    if (!payoutDone) return 3;
    return 4;
  }
}
