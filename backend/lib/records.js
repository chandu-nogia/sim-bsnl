'use strict';

const { nextId } = require('./ids');
const { logActivity } = require('./activity');

function publicCbc(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    date: row.date || '',
    name: row.name || '',
    mobile: row.mobile || '',
    landline: row.landline || '',
    amount: row.amount || '',
    transactionId: row.transactionId || '',
  };
}

function pickCbc(body) {
  const b = body && typeof body === 'object' ? body : {};
  return {
    date: String(b.date ?? '').trim(),
    name: String(b.name ?? '').trim(),
    mobile: String(b.mobile ?? '').trim(),
    landline: String(b.landline ?? '').trim(),
    amount: String(b.amount ?? '').trim(),
    transactionId: String(b.transactionId ?? b.txnId ?? '').trim(),
  };
}

function validateCbc(row) {
  if (!row.date) return 'Date choose karo';
  if (!row.name) return 'Naam likho';
  if (!/^\d{10}$/.test(row.mobile)) return '10 digit mobile';
  if (row.landline && !/^\d{6,15}$/.test(row.landline)) return 'Landline number galat';
  if (!row.amount) return 'Amount likho';
  if (!row.transactionId) return 'Transaction ID likho';
  return null;
}

function publicCtopup(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    date: row.date || '',
    name: row.name || '',
    number: row.number || '',
    amount: row.amount || '',
    status: row.status || 'Pending',
  };
}

function pickCtopup(body) {
  const b = body && typeof body === 'object' ? body : {};
  return {
    date: String(b.date ?? '').trim(),
    name: String(b.name ?? '').trim(),
    number: String(b.number ?? b.mobile ?? '').trim(),
    amount: String(b.amount ?? '').trim(),
    status: String(b.status ?? b.paymentStatus ?? 'Pending').trim() || 'Pending',
  };
}

function validateCtopup(row) {
  if (!row.date) return 'Date choose karo';
  if (!row.name) return 'Naam likho';
  if (!/^\d{10}$/.test(row.number)) return '10 digit number';
  if (!row.amount) return 'Amount likho';
  return null;
}

function makeCrud(collection, pick, validate, toPublic, section) {
  return {
    async list(db, scope = {}) {
      const q = {};
      if (scope.locationId) q.locationId = Number(scope.locationId);
      const rows = await db.collection(collection).find(q).sort({ id: 1 }).toArray();
      return rows.map(toPublic);
    },
    async add(db, body, meta) {
      const row = pick(body);
      const err = validate(row);
      if (err) return { status: 400, json: { ok: false, error: err } };
      const id = await nextId(db, collection);
      const saved = {
        id,
        ...row,
        locationId: Number(meta.locationId),
        locationName: meta.locationName || '',
        createdAt: new Date().toISOString(),
      };
      await db.collection(collection).insertOne(saved);
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        action: 'add',
        section,
        locationId: saved.locationId,
        locationName: saved.locationName,
        detail: `${row.name} add`,
      });
      return { status: 200, json: { ok: true, row: toPublic(saved) } };
    },
    async update(db, idRaw, body, meta, assertRow) {
      const id = Number.parseInt(String(idRaw), 10);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      const existing = await db.collection(collection).findOne({ id });
      if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      const blocked = await assertRow(existing);
      if (blocked) return blocked;
      const row = pick({ ...toPublic(existing), ...body });
      const err = validate(row);
      if (err) return { status: 400, json: { ok: false, error: err } };
      const saved = {
        ...row,
        id,
        locationId: existing.locationId,
        locationName: existing.locationName || meta.locationName || '',
        createdAt: existing.createdAt || '',
      };
      await db.collection(collection).updateOne({ id }, { $set: saved });
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        action: 'update',
        section,
        locationId: saved.locationId,
        locationName: saved.locationName,
        detail: `${row.name} update`,
      });
      return { status: 200, json: { ok: true, row: toPublic(saved) } };
    },
    async remove(db, idRaw, meta, assertRow) {
      const id = Number.parseInt(String(idRaw), 10);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      const existing = await db.collection(collection).findOne({ id });
      if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      const blocked = await assertRow(existing);
      if (blocked) return blocked;
      await db.collection(collection).deleteOne({ id });
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        action: 'delete',
        section,
        locationId: existing.locationId,
        locationName: existing.locationName || '',
        detail: `${existing.name || id} delete`,
      });
      return { status: 200, json: { ok: true } };
    },
  };
}

const cbc = makeCrud('cbc', pickCbc, validateCbc, publicCbc, 'cbc');
const ctopup = makeCrud('ctopup', pickCtopup, validateCtopup, publicCtopup, 'ctopup');

module.exports = { cbc, ctopup };
