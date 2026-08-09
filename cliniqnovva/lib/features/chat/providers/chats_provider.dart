import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/access_control_provider.dart';
import '../models/chat_model.dart';

/// Real-time thread list for one branch (Part 15 Task 2) — a live
/// `StreamProvider`, not a one-shot fetch, since any staff member at the
/// branch may add a message and every other staff member's inbox should
/// update without a manual refresh.
final chatsInboxStreamProvider = StreamProvider.autoDispose
    .family<List<ChatModel>, String>((ref, branchId) {
      return FirebaseService.chatsRef(branchId)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(ChatModel.fromDoc).toList());
    });

/// One thread's own doc, live — the Chat Thread screen's header (patient,
/// status) needs this in addition to its messages.
final chatDetailStreamProvider = StreamProvider.autoDispose
    .family<ChatModel?, String>((ref, chatId) {
      return FirebaseService.db
          .collection('chats')
          .doc(chatId)
          .snapshots()
          .map((doc) => doc.exists ? ChatModel.fromDoc(doc) : null);
    });

/// Real-time messages for one thread (Task 3: "real-time via Firestore
/// listeners"), oldest first.
final chatMessagesStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessageModel>, String>((ref, chatId) {
      return FirebaseService.db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots()
          .map((snap) => snap.docs.map(ChatMessageModel.fromDoc).toList());
    });

/// Unread-for-staff count on one thread (Task 2's "unread indicator") — a
/// message counts as unread-for-staff once a patient sends it and no staff
/// member has opened the thread since. Always 0 today (there's no Patient
/// App yet to author a patient-sent message), correctly wired for the
/// moment one exists.
final chatUnreadCountProvider = StreamProvider.autoDispose
    .family<int, String>((ref, chatId) {
      return FirebaseService.db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderRole', isEqualTo: 'patient')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snap) => snap.docs.length);
    });

/// Part 17 Task 4 — the sidebar's Chat badge count: total unread-for-staff
/// messages across every thread in the branch. Re-derived (one-shot counts,
/// not N persistent listeners) whenever the thread list itself changes —
/// live enough for a sidebar badge without the cost of a listener per chat.
final chatTotalUnreadProvider = FutureProvider.autoDispose
    .family<int, String>((ref, branchId) async {
      final chats = await ref.watch(chatsInboxStreamProvider(branchId).future);
      final counts = await Future.wait(
        chats.map(
          (chat) => FirebaseService.db
              .collection('chats')
              .doc(chat.id)
              .collection('messages')
              .where('senderRole', isEqualTo: 'patient')
              .where('isRead', isEqualTo: false)
              .count()
              .get(),
        ),
      );
      return counts.fold<int>(0, (total, snap) => total + (snap.count ?? 0));
    });

/// Owns every chat write (Part 15) — writes go DIRECTLY to Firestore, not
/// through `ApiService`/the Node.js backend. This is chat's established,
/// deliberate exception (see `firebase/firestore.rules`'s comment block);
/// every other feature in this app goes through the backend.
class ChatsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Task 4 — staff starting a thread on a patient's behalf uses this exact
  /// same function a future Patient App's "message this branch" action
  /// would call; only the caller's role changes, not this logic. Dedupes:
  /// reuses an existing OPEN thread for this patient+branch instead of
  /// creating a second one.
  Future<String> startChat({
    required String patientId,
    required String branchId,
    required String clinicId,
    String? appointmentId,
  }) async {
    final existing = await FirebaseService.chatsRef(branchId)
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final ref = await FirebaseService.db.collection('chats').add({
      'patientId': patientId,
      'branchId': branchId,
      'clinicId': clinicId,
      'appointmentId': appointmentId,
      'lastMessage': null,
      'lastMessageAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
    return ref.id;
  }

  /// Any staff at the chat's branch may send — the thread belongs to the
  /// branch, not to whoever started it (DONE CONDITION).
  Future<void> sendMessage(String chatId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final claims = await ref.read(userClaimsProvider.future);
    final senderId = FirebaseService.currentUserId;
    final senderRole = claims?['role'] as String? ?? 'unknown';
    if (senderId == null) return;

    final chatRef = FirebaseService.db.collection('chats').doc(chatId);
    final messageRef = await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderRole': senderRole,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    await chatRef.update({
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    // Part 25 Task 4 — pushes a notification to the patient, IF this
    // message is actually from staff (the backend re-checks senderRole
    // itself, see chats.service.js#notifyNewMessage). Best-effort: the
    // message write above already succeeded, this must never undo that or
    // surface as a failure to the sending staff member.
    try {
      await ApiService.instance.post<Map<String, dynamic>>(
        '/api/v1/chats/$chatId/notify-message',
        data: {'messageId': messageRef.id},
      );
    } catch (_) {}
  }

  /// Marks every patient-sent message in this thread read — called when a
  /// staff member opens it (Task 2's unread indicator clears on read).
  Future<void> markPatientMessagesRead(String chatId) async {
    final unread = await FirebaseService.db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderRole', isEqualTo: 'patient')
        .where('isRead', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;

    final batch = FirebaseService.db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

final chatsNotifierProvider = AsyncNotifierProvider<ChatsNotifier, void>(
  ChatsNotifier.new,
);
