// Service layer for chats (spec section 6.13, Part 15/25). Almost
// entirely empty on purpose: /chats and /chats/{id}/messages are the ONE
// deliberate exception to this app's "every write goes through the
// Node.js backend" rule (see firebase/firestore.rules' comment block) —
// real-time responsiveness requires the client to read/write Firestore
// directly, access controlled by security rules instead of this layer.
//
// notifyNewMessage() (Part 25 Task 4) is the one exception to the
// exception: a push notification needs the Admin SDK's messaging client
// the same way every other notifications.service.js trigger already
// works, which a direct client-side Firestore write can't do on its own.
// Rather than a first-of-its-kind Cloud Function (no precedent anywhere
// in this codebase), the sending client calls this right after its own
// direct write — best-effort, same as every other notify* trigger,
// re-reads the message/chat itself rather than trusting the caller.
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const notificationsService = require('./notifications.service');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

async function notifyNewMessage(chatId, messageId) {
  if (!messageId) throw httpError(400, 'messageId is required');

  const [chatDoc, messageDoc] = await Promise.all([
    db.collection('chats').doc(chatId).get(),
    db.collection('chats').doc(chatId).collection('messages').doc(messageId).get(),
  ]);
  if (!chatDoc.exists) throw httpError(404, 'Chat not found');
  if (!messageDoc.exists) throw httpError(404, 'Message not found');

  const chat = chatDoc.data();
  const message = messageDoc.data();

  // Task 4 is specifically "message FROM STAFF -> notify the patient" —
  // a patient calling this after their own message is a harmless no-op,
  // not an error, since the client can't always know in advance whether
  // it's worth calling.
  if (message.senderRole === ROLES.PATIENT) {
    return { notified: false, reason: 'not_from_staff' };
  }

  // chat.patientId is a /patients walk-in-record id (see
  // patients.service.js's module docstring, and firestore.rules'
  // isLinkedPatientAccount()) — the actual push recipient is whichever
  // Patient App account, if any, is linked to it.
  const patientDoc = await db.collection('patients').doc(chat.patientId).get();
  const linkedUid = patientDoc.exists ? patientDoc.data().linkedAppAccountId : null;
  if (!linkedUid) {
    return { notified: false, reason: 'no_linked_account' };
  }

  await notificationsService.create({
    clinicId: chat.clinicId,
    branchId: chat.branchId,
    recipientId: linkedUid,
    recipientRole: ROLES.PATIENT,
    type: 'newChatMessage',
    title: 'New message from your clinic',
    body: message.text ? message.text.slice(0, 120) : 'You have a new message.',
    data: { chatId },
    preferenceKey: 'chatMessages', // Part 26
  });

  return { notified: true };
}

module.exports = { notifyNewMessage };
