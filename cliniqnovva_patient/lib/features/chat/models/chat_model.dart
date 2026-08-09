import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `/chats/{chatId}` exactly — same model as the web dashboard's
/// `cliniqnovva/lib/features/chat/models/chat_model.dart`. Read/written
/// DIRECTLY via `cloud_firestore`, not through the backend (chat is the
/// one deliberate exception to that rule, see `firebase/firestore.rules`).
/// `patientId` here is a walk-in /patients record id (Part 21's
/// `getOrCreatePatientRecordForClinic`), never this account's own uid —
/// see `firestore.rules`' `isLinkedPatientAccount()` for why.
class ChatModel {
  const ChatModel({
    required this.id,
    required this.patientId,
    required this.branchId,
    required this.clinicId,
    this.appointmentId,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
    this.status = 'open',
  });

  final String id;
  final String patientId;
  final String branchId;
  final String clinicId;

  /// Null if this is a general inquiry, not tied to a specific visit.
  final String? appointmentId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  /// 'open' | 'closed'.
  final String status;

  factory ChatModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatModel(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      branchId: data['branchId'] as String? ?? '',
      clinicId: data['clinicId'] as String? ?? '',
      appointmentId: data['appointmentId'] as String?,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'open',
    );
  }
}

/// Mirrors `/chats/{chatId}/messages/{messageId}` exactly. Messages are
/// soft-deleted only, never hard-deleted — `firestore.rules` denies
/// `delete` outright on this subcollection, and no delete affordance
/// exists in either client's UI.
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime? createdAt;
  final bool isRead;

  factory ChatMessageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }
}
