'use strict';

const { nextId } = require('./ids');
const { logActivity } = require('./activity');
const { moneyNumber } = require('./password');
const { withAlive } = require('./alive');
const { addSim } = require('./sims');
const { cbc, ctopup } = require('./records');

async function getStock(db, locationId) {
  const id = Number(locationId);
  if (!id) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
  const row = await db.collection('stock').findOne({ locationId: id });
  return {
    status: 200,
    json: {
      ok: true,
      stock: {
        locationId: id,
        qty: Number(row?.qty || 0),
        lowAt: Number(row?.lowAt || 20),
        note: row?.note || '',
        updatedAt: row?.updatedAt || '',
        low: Number(row?.qty || 0) <= Number(row?.lowAt || 20),
      },
    },
  };
}

async function saveStock(db, user, locationId, body) {
  const id = Number(locationId);
  if (!id) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
  const qty = Number.parseInt(String(body?.qty ?? ''), 10);
  const lowAt = Number.parseInt(String(body?.lowAt ?? '20'), 10);
  if (!Number.isFinite(qty) || qty < 0) return { status: 400, json: { ok: false, error: 'Stock quantity likho' } };
  const now = new Date().toISOString();
  await db.collection('stock').updateOne(
    { locationId: id },
    {
      $set: {
        locationId: id,
        qty,
        lowAt: Number.isFinite(lowAt) && lowAt >= 0 ? lowAt : 20,
        note: String(body?.note || '').trim(),
        updatedBy: user.email,
        updatedAt: now,
      },
      $setOnInsert: { createdAt: now },
    },
    { upsert: true },
  );
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'update',
    section: 'stock',
    locationId: id,
    locationName: user.locationName,
    detail: `${user.name || user.email} set SIM stock ${qty}`,
  });
  return getStock(db, id);
}

async function listClosing(db, locationId, query = {}) {
  const id = Number(locationId);
  if (!id) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
  const from = String(query.from || '').slice(0, 10);
  const q = { locationId: id };
  if (from) q.date = from;
  const rows = await db.collection('closing').find(q).sort({ date: -1, id: -1 }).limit(60).toArray();
  return { status: 200, json: { ok: true, rows } };
}

async function addClosing(db, user, locationId, body) {
  const id = Number(locationId);
  if (!id) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
  const date = String(body?.date || new Date().toISOString().slice(0, 10)).slice(0, 10);
  const exists = await db.collection('closing').findOne({ locationId: id, date, createdBy: user.email });
  if (exists) return { status: 400, json: { ok: false, error: 'Aaj ka closing already submit ho chuka hai' } };
  const now = new Date().toISOString();
  const row = {
    id: await nextId(db, 'closing'),
    locationId: id,
    locationName: user.locationName || '',
    date,
    sims: Number(body?.sims || 0),
    cbcCount: Number(body?.cbcCount || 0),
    cbcAmount: moneyNumber(body?.cbcAmount),
    ctopupCount: Number(body?.ctopupCount || 0),
    ctopupAmount: moneyNumber(body?.ctopupAmount),
    cash: moneyNumber(body?.cash),
    note: String(body?.note || '').trim(),
    status: 'pending',
    createdBy: user.email,
    createdAt: now,
    updatedAt: now,
  };
  await db.collection('closing').insertOne(row);
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'add',
    section: 'closing',
    locationId: id,
    locationName: row.locationName,
    detail: `${user.name || user.email} submitted daily closing for ${date}`,
  });
  return { status: 200, json: { ok: true, row } };
}

async function reviewClosing(db, user, idRaw, body) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const row = await db.collection('closing').findOne({ id });
  if (!row) return { status: 404, json: { ok: false, error: 'Closing nahi mili' } };
  const status = body?.status === 'rejected' ? 'rejected' : 'approved';
  await db.collection('closing').updateOne(
    { id },
    { $set: { status, reviewedBy: user.email, updatedAt: new Date().toISOString() } },
  );
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'update',
    section: 'closing',
    locationId: row.locationId,
    locationName: row.locationName,
    detail: `${user.name || user.email} ${status} closing #${id}`,
  });
  return { status: 200, json: { ok: true } };
}

function asRows(body) {
  if (Array.isArray(body?.rows)) return body.rows;
  if (Array.isArray(body)) return body;
  return [];
}

async function importRows(db, meta, kind, body) {
  const rows = asRows(body);
  if (!rows.length) return { status: 400, json: { ok: false, error: 'CSV rows khali hain' } };
  if (rows.length > 400) return { status: 400, json: { ok: false, error: 'Ek baar mein 400 rows tak' } };
  let added = 0;
  const errors = [];
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i] || {};
    let out;
    if (kind === 'sims') out = await addSim(db, row, meta);
    else if (kind === 'cbc') out = await cbc.add(db, row, meta);
    else out = await ctopup.add(db, row, meta);
    if (out.status === 200) added += 1;
    else errors.push({ index: i + 1, error: out.json?.error || 'Fail' });
  }
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'add',
    section: kind,
    locationId: meta.locationId,
    locationName: meta.locationName,
    detail: `${meta.name || meta.email} imported ${added}/${rows.length} ${kind} rows`,
  });
  return { status: 200, json: { ok: true, added, failed: errors.length, errors: errors.slice(0, 20) } };
}

async function todayStats(db, locationId) {
  const id = Number(locationId);
  const day = new Date().toISOString().slice(0, 10);
  const q = withAlive({ locationId: id, date: day });
  const [sims, cbcRows, top] = await Promise.all([
    db.collection('sims').countDocuments(q),
    db.collection('cbc').find(q).toArray(),
    db.collection('ctopup').find(q).toArray(),
  ]);
  return {
    date: day,
    sims,
    cbcCount: cbcRows.length,
    cbcAmount: cbcRows.reduce((a, r) => a + moneyNumber(r.amountNum ?? r.amount), 0),
    ctopupCount: top.length,
    ctopupAmount: top.reduce((a, r) => a + moneyNumber(r.amountNum ?? r.amount), 0),
  };
}

module.exports = {
  getStock,
  saveStock,
  listClosing,
  addClosing,
  reviewClosing,
  importRows,
  todayStats,
};
