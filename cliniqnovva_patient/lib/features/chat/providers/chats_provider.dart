import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/linked_patient_ids_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';
import '../models/chat_model.dart';

/// Every chat thread across every clinic this patient has ever interacted
/// with (Part 25 Task 1: "sorted by lastMessageAt") — a live
/// `StreamProvider`, not a one-shot fetch, same as the web dashboard's
/// `chatsInboxStreamProvider`. `whereIn` caps at 10 values; a patient with
/// more than 10 linked clinics is not a case this app needs to handle today.
final myChatsStreamProvider = StreamProvider.autoDispose<List<ChatModel>>((ref) async* {
  final linkedIds = await ref.watch(linkedPatientIdsProvider.future);
  if (linkedIds.isEmpty) {
    yield <ChatModel>[];
    return;
  }
  yield* FirebaseService.db
      .collection('chats')
      .where('patientId', whereIn: linkedIds.take(10).toList())
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(ChatModel.fromDoc).toList());
});

/// One thread's own doc, live — the header (clinic, appointment context).
final chatDetailStreamProvider = StreamProvider.autoDispose.family<ChatModel?, String>((ref, chatId) {
  return FirebaseService.db
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .map((doc) => doc.exists ? ChatModel.fromDoc(doc) : null);
});

/// Real-time messages for one thread (Task 2: "real-time via Firestore
/// listeners"), oldest first.
final chatMessagesStreamProvider = StreamProvider.autoDispose.family<List<ChatMessageModel>, String>((ref, chatId) {
  return FirebaseService.db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map(ChatMessageModel.fromDoc).toList());
});

/// Unread-for-PATIENT count on one thread (Task 1's "unread indicator") —
/// the mirror image of the web dashboard's `chatUnreadCountProvider`
/// (unread-for-staff, keyed on `senderRole == 'patient'`). Filters
/// `senderRole != 'patient'` client-side rather than as a second Firestore
/// `where`, so this never needs its own composite index beyond the plain
/// `isRead` equality filter.
final chatUnreadCountProvider = StreamProvider.autoDispose.family<int, String>((ref, chatId) {
  return FirebaseService.db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.where((d) => d.data()['senderRole'] != 'patient').length);
});

/// Total unread-for-PATIENT count ACROSS every chat thread — the Home top
/// bar's chat button badge. A one-shot sum (not a combined live stream —
/// `chatUnreadCountProvider` is per-thread and there's no cheap way to
/// merge N Firestore listeners into one without a new dependency) over the
/// same per-thread query [chatUnreadCountProvider] already uses; re-runs
/// whenever this provider is watched/invalidated, same as any other
/// FutureProvider, rather than pushing live updates.
final totalChatUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final chats = await ref.watch(myChatsStreamProvider.future);
  final counts = await Future.wait(
    chats.map((chat) async {
      final snap = await FirebaseService.db
          .collection('chats')
          .doc(chat.id)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();
      return snap.docs.where((d) => d.data()['senderRole'] != 'patient').length;
    }),
  );
  return counts.fold<int>(0, (a, b) => a + b);
});

/// Owns every chat write (Task 3) — writes go DIRECTLY to Firestore, the
/// SAME functions/field shapes the web dashboard's `ChatsNotifier` already
/// uses (mirrored exactly, not reimplemented), just called from the patient
/// side now. The one addition here beyond a straight mirror: resolving the
/// caller's own walk-in patientId first (`resolvePatientIdForClinic`, Part
/// 25's `POST /api/v1/patients/resolve-for-clinic`) — the web app never
/// needed this because staff already had a patientId in hand (search
/// result) before calling `startChat`.
class ChatsNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> resolvePatientIdForClinic({required String clinicId, required String branchId}) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/patients/resolve-for-clinic',
      data: {'clinicId': clinicId, 'branchId': branchId},
    );
    return response.data!['patientId'] as String;
  }

  /// Task 1: "starting a new thread requires no appointment or prior
  /// relationship" — dedupes against an existing OPEN thread with this
  /// branch first, exactly like the web dashboard's `startChat`.
  Future<String> startChat({required String clinicId, required String branchId, String? appointmentId}) async {
    final patientId = await resolvePatientIdForClinic(clinicId: clinicId, branchId: branchId);

    final existing = await FirebaseService.db
        .collection('chats')
        .where('patientId', isEqualTo: patientId)
        .where('branchId', isEqualTo: branchId)
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

  Future<void> sendMessage(String chatId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final senderId = FirebaseService.currentUserId;
    if (senderId == null) return;

    final chatRef = FirebaseService.db.collection('chats').doc(chatId);
    final messageRef = await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderRole': 'patient',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    await chatRef.update({
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    // Task 4 is "message FROM STAFF -> push to patient", so this call is a
    // harmless no-op for a patient-sent message (the backend checks
    // senderRole itself) — kept symmetric with the web dashboard's own
    // post-send call rather than each client having to reason about
    // directionality. Best-effort: never blocks the send that already
    // succeeded above.
    try {
      await ApiService.instance.post<Map<String, dynamic>>(
        '/api/v1/chats/$chatId/notify-message',
        data: {'messageId': messageRef.id},
      );
    } catch (_) {}
  }

  /// Marks every staff-sent message in this thread read — called when the
  /// patient opens the thread (Task 1's unread indicator clears on read).
  Future<void> markStaffMessagesRead(String chatId) async {
    final unread = await FirebaseService.db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();
    final staffMessages = unread.docs.where((d) => d.data()['senderRole'] != 'patient');
    if (staffMessages.isEmpty) return;

    final batch = FirebaseService.db.batch();
    for (final doc in staffMessages) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

final chatsNotifierProvider = AsyncNotifierProvider.autoDispose<ChatsNotifier, void>(ChatsNotifier.new);
