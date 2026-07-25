// Service layer for chats — INTENTIONALLY EMPTY, permanently (spec section
// 6.13, Part 15). This is not a "not built yet" stub like the others once
// were: /chats and /chats/{id}/messages are the ONE deliberate exception to
// this app's "every write goes through the Node.js backend" rule (see
// firebase/firestore.rules' comment block, and FirebaseService.chatsRef()
// already reserved for this in the Flutter client since Part 1). Real-time
// responsiveness requires the client to read/write Firestore directly, with
// access control enforced by security rules instead of by this layer — so
// there is no backend business logic for chats to hold, now or later.
module.exports = {};
