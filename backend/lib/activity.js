'use strict';

const { nextId } = require('./ids');

async function logActivity(db, row) {
  const id = await nextId(db, 'activity');
  const saved = {
    id,
    at: new Date().toISOString(),
    email: row.email || '',
    role: row.role || '',
    action: row.action || '',
    section: row.section || '',
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
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
    role: row.role || '',
    action: row.action || '',
    section: row.section || '',
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    detail: row.detail || '',
  };
}

async function listActivity(db, user, limitRaw) {
  const limit = Math.min(100, Math.max(10, Number(limitRaw) || 40));
  const q = user.role === 'admin' ? {} : { locationId: Number(user.locationId) };
  const rows = await db.collection('activity').find(q).sort({ id: -1 }).limit(limit).toArray();
  return rows.map(publicActivity);
}

module.exports = { logActivity, listActivity, publicActivity };
