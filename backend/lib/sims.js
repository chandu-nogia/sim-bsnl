'use strict';

const { nextId } = require('./ids');
const { logActivity } = require('./activity');
const { mongoListQuery, applyTextSearch } = require('./rbac');
const { locationMatchQuery } = require('./location_resolve');
const { withAlive } = require('./alive');

function publicRow(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    date: row.date || '',
    sno: row.sno ?? 0,
    name: row.name || '',
    alt: row.alt || '',
    frc: row.frc || '',
    type: row.type || 'CYMN',
    mobile: row.mobile || '',
    sim: row.sim || '',
    last6: row.last6 || '',
    status: row.status || 'Issued',
    createdBy: row.createdBy || '',
    employeeId: row.employeeId ? Number(row.employeeId) : null,
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
    note: row.note || '',
  };
}

function pickBody(body) {
  const b = body && typeof body === 'object' ? body : {};
  const sim = String(b.sim ?? b.simNo ?? '').trim();
  const digits = sim.replace(/\D/g, '');
  const last6 =
    String(b.last6 ?? b.simLast6 ?? '').trim() ||
    (digits.length >= 6 ? digits.slice(-6) : digits);
  return {
    date: String(b.date ?? '').trim(),
    sno: Number.parseInt(String(b.sno ?? ''), 10) || 0,
    name: String(b.name ?? '').trim(),
    alt: String(b.alt ?? b.altNumber ?? '').trim(),
    frc: String(b.frc ?? '').trim(),
    type: String(b.type ?? 'CYMN').trim() || 'CYMN',
    mobile: String(b.mobile ?? '').trim(),
    sim,
    last6,
    status: String(b.status ?? 'Issued').trim() || 'Issued',
    note: String(b.note ?? b.remarks ?? '').trim(),
  };
}

function validate(_row) {
  return null;
}

async function listSims(db, scope = {}) {
  let q = withAlive(mongoListQuery(scope));
  q = applyTextSearch(q, ['name', 'mobile', 'sim', 'last6', 'note'], scope.q);
  const from = String(scope.from || '').slice(0, 10);
  const to = String(scope.to || '').slice(0, 10);
  if (from || to) {
    q.date = {};
    if (from) q.date.$gte = from;
    if (to) q.date.$lte = to;
  }
  const page = Math.max(1, Number(scope.page) || 1);
  const limit = Math.min(500, Math.max(20, Number(scope.limit) || 300));
  const skip = (page - 1) * limit;
  const col = db.collection('sims');
  const total = await col.countDocuments(q);
  const rows = await col.find(q).sort({ id: -1 }).skip(skip).limit(limit).toArray();
  return { rows: rows.map(publicRow), total, page, limit };
}

async function addSim(db, body, meta) {
  const row = pickBody(body);
  const err = validate(row);
  if (err) return { status: 400, json: { ok: false, error: err } };
  const locId = Number(meta.locationId);
  const dupOr = [];
  if (row.mobile) dupOr.push({ mobile: row.mobile });
  if (row.sim) dupOr.push({ sim: row.sim });
  if (dupOr.length && body?.force !== true) {
    const dup = await db.collection('sims').findOne(withAlive({
      locationId: locId,
      $or: dupOr,
    }));
    if (dup) {
      return {
        status: 409,
        json: { ok: false, error: 'Is location mein ye mobile/SIM pehle se hai', duplicate: true },
      };
    }
  }
  if (!row.sno) {
    const q = { locationId: Number(meta.locationId) };
    const last = await db.collection('sims').find(q).sort({ sno: -1 }).limit(1).next();
    row.sno = (last && Number(last.sno) ? Number(last.sno) : 0) + 1;
  }
  const id = await nextId(db, 'sims');
  const now = new Date().toISOString();
  const saved = {
    id,
    ...row,
    locationId: Number(meta.locationId),
    locationName: meta.locationName || '',
    createdBy: meta.email || '',
    employeeId: meta.userId ? Number(meta.userId) : null,
    createdAt: now,
    updatedAt: now,
  };
  await db.collection('sims').insertOne(saved);
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'add',
    section: 'sim',
    locationId: saved.locationId,
    locationName: saved.locationName,
    detail: `${meta.name || meta.email} added new user ${row.name} in ${saved.locationName}`,
  });
  return { status: 200, json: { ok: true, row: publicRow(saved) } };
}

async function updateSim(db, idRaw, body, meta, assertRow) {
  const id = Number.parseInt(String(idRaw), 10);
  const locId = Number(meta.locationId);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  if (!locId) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
  const existing = await db.collection('sims').findOne({ id, ...locationMatchQuery(locId) });
  if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
  const blocked = await assertRow(existing);
  if (blocked) return blocked;
  const row = pickBody({ ...publicRow(existing), ...body });
  const err = validate(row);
  if (err) return { status: 400, json: { ok: false, error: err } };
  const saved = {
    ...row,
    id,
    locationId: Number(existing.locationId),
    locationName: existing.locationName || meta.locationName || '',
    createdBy: existing.createdBy || meta.email || '',
    employeeId: existing.employeeId || (meta.userId ? Number(meta.userId) : null),
    createdAt: existing.createdAt || '',
    updatedAt: new Date().toISOString(),
  };
  await db.collection('sims').updateOne({ _id: existing._id }, { $set: saved });
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'update',
    section: 'sim',
    locationId: saved.locationId,
    locationName: saved.locationName,
    detail: `${meta.name || meta.email} updated user ${row.name} in ${saved.locationName}`,
  });
  return { status: 200, json: { ok: true, row: publicRow(saved) } };
}

async function deleteSim(db, idRaw, meta, assertRow) {
  const id = Number.parseInt(String(idRaw), 10);
  const locId = Number(meta.locationId);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  if (!locId) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
  const existing = await db.collection('sims').findOne({ id, ...locationMatchQuery(locId) });
  if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
  const blocked = await assertRow(existing);
  if (blocked) return blocked;
  await db.collection('sims').updateOne(
    { _id: existing._id },
    { $set: { deletedAt: new Date().toISOString(), deletedBy: meta.email || '', updatedAt: new Date().toISOString() } },
  );
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'delete',
    section: 'sim',
    locationId: existing.locationId,
    locationName: existing.locationName || '',
    detail: `${meta.name || meta.email} deleted user ${existing.name || id} in ${existing.locationName || ''}`,
  });
  return { status: 200, json: { ok: true } };
}

module.exports = { publicRow, pickBody, validate, listSims, addSim, updateSim, deleteSim };
