// Service layer for publicHolidays (spec section 1 / 9).
// Read-only for now (Part 8's Doctor Schedule screen needs to display and
// auto-block them) — managing the list (create/update/remove) is a later
// part's scope; those controller handlers stay 501 stubs until then.
const { db } = require('../config/firebase-admin');

async function list() {
  const snapshot = await db.collection('publicHolidays').orderBy('date', 'asc').get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function getById(id) {
  const doc = await db.collection('publicHolidays').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

module.exports = { list, getById };
