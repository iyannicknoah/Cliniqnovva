// In-memory stand-in for Firebase Admin's Messaging SDK — covers only
// `.send()`, the one method notifications.service.js#sendPush() calls.
// Real firebase-admin.js exports `messaging: {}` in test mode before this
// (an empty object, so `sendPush`'s `messaging.send(...)` call always threw
// and got silently swallowed by its own try/catch) — nothing ever actually
// verified a push was attempted. This records every call so a test can
// assert on it directly (Part 22's reminder job DONE CONDITION: "confirm a
// push notification arrives").
class MockMessaging {
  constructor() {
    this.sent = [];
  }

  async send(message) {
    this.sent.push(message);
    return `mock-message-id-${this.sent.length}`;
  }
}

module.exports = { MockMessaging };
