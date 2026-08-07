// Chat is the one collection Cliniqnovva clients write to DIRECTLY via the
// Firestore client SDK (see firestore.rules's own header comment and
// docs/security-review.md finding #2) — its access scoping therefore lives
// entirely in firebase/firestore.rules, not in any backend service function
// this suite can exercise. Properly testing security rules means running
// them against the Firebase Emulator Suite (@firebase/rules-unit-testing),
// which needs a local Java runtime + the emulator binary — not available in
// this environment (same constraint noted throughout this build for
// browser-screenshot verification).
//
// This is a static, textual regression guard instead: it asserts the
// specific scoping predicates docs/security-review.md's manual review
// found correct are still literally present in the rules file. It cannot
// catch every possible rules bug, but it DOES fail loudly if someone
// "simplifies" the chat rule block and accidentally drops branch scoping,
// the patient-owner check, or the hard-delete ban — the specific mistakes
// most likely to reintroduce a real gap here.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const rulesPath = path.resolve(__dirname, '../../firebase/firestore.rules');
const rules = fs.readFileSync(rulesPath, 'utf8');

function chatBlock() {
  const start = rules.indexOf("match /chats/{chatId} {");
  const end = rules.indexOf('\n  }\n}', start); // end of the outer service block
  assert.ok(start !== -1, 'firestore.rules must still define match /chats/{chatId}');
  return rules.slice(start, end === -1 ? rules.length : end);
}

test('chat rules: read is scoped to the chat\'s own patient, same-branch staff, or Super Admin', () => {
  const block = chatBlock();
  const readSection = block.slice(block.indexOf('allow read:'), block.indexOf('allow create:'));
  assert.match(readSection, /request\.auth\.uid == resource\.data\.patientId/);
  assert.match(readSection, /inSameBranch\(resource\.data\.branchId\)/);
  assert.match(readSection, /isSuperAdmin\(\)/);
});

test('chat rules: create requires the caller to be the chat\'s own patient or staff at its branch', () => {
  const block = chatBlock();
  const createSection = block.slice(block.indexOf('allow create:'), block.indexOf('allow update:'));
  assert.match(createSection, /request\.auth\.uid == request\.resource\.data\.patientId/);
  assert.match(createSection, /inSameBranch\(request\.resource\.data\.branchId\)/);
});

test('chat rules: delete is always denied — messages are soft-deleted only', () => {
  const block = chatBlock();
  assert.match(block, /allow delete: if false;/);
});

test('chat rules: messages subcollection re-derives scope from the PARENT chat doc, not its own fields', () => {
  const block = chatBlock();
  const messagesBlock = block.slice(block.indexOf('match /messages/{messageId}'));
  assert.match(messagesBlock, /chatDoc\(\)\.patientId/);
  assert.match(messagesBlock, /chatDoc\(\)\.branchId/);
  assert.match(messagesBlock, /senderId == request\.auth\.uid/, 'a message create must assert the sender is who they claim to be');
});

test('security rules: auditLogs (removed 2026-07-24, restored 2026-07-29) and patientMergeLogs are both read-scoped-write-denied (append-only via backend Admin SDK only)', () => {
  const auditLogSection = rules.slice(rules.indexOf('match /auditLogs/'), rules.indexOf('match /patientMergeLogs/'));
  assert.match(auditLogSection, /allow read: if isSuperAdmin\(\) \|\| isClinicAdmin\(\);/);
  assert.match(auditLogSection, /allow write: if false;/);

  const mergeLogSection = rules.slice(rules.indexOf('match /patientMergeLogs/'), rules.indexOf('match /chats/'));
  assert.match(mergeLogSection, /allow write: if false;/);
});

test('security rules: reviews are fully write-denied to clients (soft-hide is backend-service-enforced only)', () => {
  const reviewsSection = rules.slice(rules.indexOf('match /reviews/'), rules.indexOf('match /publicHolidays/'));
  assert.match(reviewsSection, /allow write: if false;/);
});
