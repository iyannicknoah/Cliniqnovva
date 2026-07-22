// Service layer for branches (spec section 4 / 6.2 / 9).
// Only list/getById/create are implemented for real right now — Part 3 needs
// them for the organization detail view's read-only branch list and the
// Super Admin "create branch on this org's behalf" support-exception path.
// Full branch management (update/remove, Organization Admin's own creation
// flow) is Part 6's scope.
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');

async function list(organizationId) {
  const snapshot = await db.collection('branches').where('organizationId', '==', organizationId).get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function getById(id) {
  const doc = await db.collection('branches').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

/**
 * @param {{actorId: string, actorRole: string}} actor - used to log whether this
 *   was a Super Admin acting on an organization's behalf (Part 3 Task 3).
 */
async function create({ organizationId, name, address, phone }, { actorId, actorRole }) {
  const data = {
    organizationId,
    name,
    address: address || null,
    phone: phone || null,
    isActive: true,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('branches').add(data);

  const onBehalfOfOrg = actorRole === ROLES.SUPER_ADMIN;
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action: onBehalfOfOrg ? 'branch.createdOnBehalfOfOrganization' : 'branch.created',
    targetCollection: 'branches',
    targetId: ref.id,
    organizationId,
    timestamp: new Date().toISOString(),
  });

  return { id: ref.id, ...data };
}

module.exports = { list, getById, create };
