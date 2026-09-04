'use strict';

const { nextId } = require('./ids');
const { assignedIds } = require('./rbac');

async function logActivity(db, row) {
  const id = await nextId(db, 'activity');
  const saved = {
    id,
    at: new Date().toISOString(),
    email: row.email || '',
    name: row.name || '',
    role: row.role || '',
    action: row.action || '',
    section: row.section || '',
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    recordId: row.recordId || null,
    ip: row.ip || '',
    detail: row.detail || '',
  };
  await db.collection('activity').insertOne(saved);
  return saved;
}

function publicActivity(row) {
  return {
    id: Number(row.id),
    at: row.at || '',
    email: row.email || '',
    name: row.name || '',
    role: row.role || '',
    action: row.action || '',
    section: row.section || '',
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    recordId: row.recordId || null,
    ip: row.ip || '',
    detail: row.detail || '',
  };
}

async function listActivity(db, user, query = {}) {
  const ids = assignedIds(user);
  const q = {};
  if (ids !== null) {
    q.locationId = { $in: ids.length ? ids : [-1] };
  }
  const locationId = Number.parseInt(String(query.locationId || ''), 10) || 0;
  if (locationId) {
    if (ids !== null && !ids.includes(locationId)) {
      return { error: 'Is jagah ki permission nahi', status: 403 };
    }
    q.locationId = locationId;
  }
  const email = String(query.employee || query.email || '').trim().toLowerCase();
  if (email) q.email = email;
  const action = String(query.action || '').trim();
  if (action) q.action = action;
  const section = String(query.section || '').trim();
  if (section) q.section = section;
  const search = String(query.q || query.search || '').trim();
  if (search) {
    q.detail = { $regex: search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
  }
  const from = String(query.from || '').slice(0, 10);
  const to = String(query.to || '').slice(0, 10);
  if (from || to) {
    q.at = {};
    if (from) q.at.$gte = `${from}T00:00:00.000Z`;
    if (to) q.at.$lte = `${to}T23:59:59.999Z`;
  }
  const page = Math.max(1, Number(query.page) || 1);
  const limit = Math.min(100, Math.max(10, Number(query.limit) || 40));
  const skip = (page - 1) * limit;
  const col = db.collection('activity');
  const total = await col.countDocuments(q);
  const rows = await col.find(q).sort({ id: -1 }).skip(skip).limit(limit).toArray();
  return { rows: rows.map(publicActivity), total, page, limit };
}

module.exports = { logActivity, listActivity, publicActivity };
