'use strict';

const { assignedIds } = require('./rbac');
const { logActivity } = require('./activity');

const TYPES = {
  sims: 'sims',
  sim: 'sims',
  portal: 'sims',
  cbc: 'cbc',
  ctopup: 'ctopup',
};

function resolveType(raw) {
  return TYPES[String(raw || '').toLowerCase()] || '';
}

function publicDeleted(row, type) {
  return {
    id: Number(row.id),
    type,
    name: row.name || '',
    mobile: row.mobile || row.number || '',
    amount: row.amount || '',
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    deletedAt: row.deletedAt || '',
    deletedBy: row.deletedBy || '',
    createdAt: row.createdAt || '',
  };
}

async function listDeleted(db, user, query = {}) {
  const ids = assignedIds(user);
  const type = resolveType(query.type);
  const cols = type ? [type] : ['sims', 'cbc', 'ctopup'];
  const locFilter = Number.parseInt(String(query.locationId || ''), 10) || 0;
  if (ids !== null && locFilter && !ids.includes(locFilter)) {
    return { status: 403, json: { ok: false, error: 'Is jagah ki permission nahi' } };
  }
  const q = { deletedAt: { $exists: true, $ne: null } };
  if (ids !== null) q.locationId = { $in: ids.length ? ids : [-1] };
  else if (locFilter) q.locationId = locFilter;
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const rows = [];
  for (const col of cols) {
    const found = await db.collection(col).find(q).sort({ deletedAt: -1 }).limit(200).toArray();
    for (const r of found) {
      if (r.deletedAt && r.deletedAt < cutoff) continue;
      rows.push(publicDeleted(r, col));
    }
  }
  rows.sort((a, b) => String(b.deletedAt).localeCompare(String(a.deletedAt)));
  return { status: 200, json: { ok: true, rows, total: rows.length } };
}

async function restoreRow(db, user, typeRaw, idRaw) {
  const type = resolveType(typeRaw);
  const id = Number.parseInt(String(idRaw), 10);
  if (!type || !id) return { status: 400, json: { ok: false, error: 'Invalid recycle item' } };
  const ids = assignedIds(user);
  const row = await db.collection(type).findOne({ id, deletedAt: { $exists: true, $ne: null } });
  if (!row) return { status: 404, json: { ok: false, error: 'Recycle item nahi mila' } };
  if (ids !== null && !ids.includes(Number(row.locationId))) {
    return { status: 403, json: { ok: false, error: 'Ye entry dusri jagah ki hai' } };
  }
  await db.collection(type).updateOne(
    { _id: row._id },
    { $unset: { deletedAt: '', deletedBy: '' }, $set: { updatedAt: new Date().toISOString() } },
  );
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'update',
    section: 'recycle',
    locationId: row.locationId,
    locationName: row.locationName,
    detail: `${user.name || user.email} restored ${type} #${id} in ${row.locationName || ''}`,
  });
  return { status: 200, json: { ok: true } };
}

async function purgeRow(db, user, typeRaw, idRaw) {
  if (user.role !== 'admin') return { status: 403, json: { ok: false, error: 'Sirf admin permanent delete kar sakta hai' } };
  const type = resolveType(typeRaw);
  const id = Number.parseInt(String(idRaw), 10);
  if (!type || !id) return { status: 400, json: { ok: false, error: 'Invalid recycle item' } };
  const row = await db.collection(type).findOne({ id, deletedAt: { $exists: true, $ne: null } });
  if (!row) return { status: 404, json: { ok: false, error: 'Recycle item nahi mila' } };
  await db.collection(type).deleteOne({ _id: row._id });
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'delete',
    section: 'recycle',
    locationId: row.locationId,
    locationName: row.locationName,
    recordId: id,
    detail: `${user.name || user.email} permanently deleted ${type} #${id}`,
  });
  return { status: 200, json: { ok: true } };
}

module.exports = { listDeleted, restoreRow, purgeRow };
