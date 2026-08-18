// Controller for /api/v1/staff — spec section 6.3 / 6.5 / 9 (Part 8).
const staffService = require('../services/staff.service');
const { ROLES } = require('../middleware/requireRole');

function resolveClinicId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.clinicId;
}

/** Branch Admin is always pinned to their own branch; Clinic Admin/Super Admin pick one. */
function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

async function list(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.query.clinicId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    const branchId = resolveBranchId(req, req.query.branchId);

    // A Doctor only ever sees themself (spec 6.5: "Doctor (view own)").
    if (req.user?.role === ROLES.DOCTOR) {
      const self = await staffService.getById(req.user.uid);
      return res.json({ staff: self ? [self] : [] });
    }

    const staff = await staffService.list({ clinicId, branchId });
    res.json({ staff });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    // A Doctor may only ever fetch their own record (spec 6.5).
    const targetId = req.user?.role === ROLES.DOCTOR ? req.user.uid : req.params.id;
    const staffMember = await staffService.getById(targetId);
    if (!staffMember) return res.status(404).json({ error: 'Staff member not found' });
    if (req.scope.level !== 'platform' && staffMember.clinicId !== req.scope.clinicId) {
      return res.status(403).json({ error: 'This staff member belongs to a different clinic' });
    }
    res.json({ staff: staffMember });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const { email, password, role, displayName, phone, specialty, departmentIds } = req.body;
    if (!email || !password || !role || !displayName) {
      return res.status(400).json({ error: 'email, password, role, and displayName are required' });
    }

    const clinicId = resolveClinicId(req, req.body.clinicId);
    const branchId = resolveBranchId(req, req.body.branchId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    if (!branchId) return res.status(400).json({ error: 'branchId is required' });

    const staffMember = await staffService.create(
      {
        email,
        password,
        name: displayName,
        role,
        clinicId,
        branchId,
        phone,
        specialty,
        departmentIds,
      },
      { actorId: req.user?.uid, actorRole: req.user?.role, scope: req.scope }
    );
    res.status(201).json({ staff: staffMember });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const staffMember = await staffService.update(
      req.params.id,
      {
        name: req.body.name,
        phone: req.body.phone,
        email: req.body.email,
        specialty: req.body.specialty,
        departmentIds: req.body.departmentIds,
      },
      { actorId: req.user?.uid, actorRole: req.user?.role, scope: req.scope }
    );
    res.json({ staff: staffMember });
  } catch (err) {
    next(err);
  }
}

async function setStatus(req, res, next) {
  try {
    const { isActive } = req.body;
    if (typeof isActive !== 'boolean') {
      return res.status(400).json({ error: 'isActive (boolean) is required' });
    }
    const staffMember = await staffService.setStatus(req.params.id, isActive, {
      actorId: req.user?.uid,
      actorRole: req.user?.role,
      scope: req.scope,
    });
    res.json({ staff: staffMember });
  } catch (err) {
    next(err);
  }
}

async function uploadPhoto(req, res, next) {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file provided (field name must be "file")' });
    const staffMember = await staffService.setPhoto(
      req.params.id,
      { buffer: req.file.buffer, contentType: req.file.mimetype },
      { actorId: req.user?.uid, actorRole: req.user?.role, scope: req.scope }
    );
    res.json({ staff: staffMember });
  } catch (err) {
    next(err);
  }
}

async function viewPhoto(req, res, next) {
  try {
    const photo = await staffService.getPhoto(req.params.id);
    if (!photo) return res.status(404).json({ error: 'No photo uploaded for this doctor' });
    res.set('Content-Type', photo.contentType || 'image/jpeg');
    res.set('Cache-Control', 'private, max-age=300');
    res.send(photo.body);
  } catch (err) {
    next(err);
  }
}

async function setSchedule(req, res, next) {
  try {
    const staffMember = await staffService.setSchedule(
      req.params.doctorId,
      req.body.schedule,
      req.body.breakMinutes,
      {
        actorId: req.user?.uid,
        actorRole: req.user?.role,
        scope: req.scope,
      }
    );
    res.json({ staff: staffMember });
  } catch (err) {
    next(err);
  }
}

async function addBlockedSlot(req, res, next) {
  try {
    const { date, startTime, endTime, reason } = req.body;
    const result = await staffService.addBlockedSlot(
      req.params.doctorId,
      { date, startTime, endTime, reason },
      { actorId: req.user?.uid, actorRole: req.user?.role, scope: req.scope }
    );
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented: staff are deactivated, never hard-deleted' });
}

module.exports = {
  list,
  getById,
  create,
  update,
  setStatus,
  uploadPhoto,
  viewPhoto,
  setSchedule,
  addBlockedSlot,
  remove,
};
