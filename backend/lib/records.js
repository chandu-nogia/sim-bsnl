'use strict';

async function nextId(db, key) {
  const result = await db.collection('counters').findOneAndUpdate(
    { _id: key },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' },
  );
  const seq = result && (result.seq ?? result.value?.seq);
  return Number(seq) || 1;
}

function publicCbc(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
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
    name: String(b.name ?? '').trim(),
    mobile: String(b.mobile ?? '').trim(),
    landline: String(b.landline ?? '').trim(),
    amount: String(b.amount ?? '').trim(),
    transactionId: String(b.transactionId ?? b.txnId ?? '').trim(),
  };
}

function validateCbc(row) {
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
    name: row.name || '',
    number: row.number || '',
    amount: row.amount || '',
    status: row.status || 'Pending',
  };
}

function pickCtopup(body) {
  const b = body && typeof body === 'object' ? body : {};
  return {
    name: String(b.name ?? '').trim(),
    number: String(b.number ?? b.mobile ?? '').trim(),
    amount: String(b.amount ?? '').trim(),
    status: String(b.status ?? b.paymentStatus ?? 'Pending').trim() || 'Pending',
  };
}

function validateCtopup(row) {
  if (!row.name) return 'Naam likho';
  if (!/^\d{10}$/.test(row.number)) return '10 digit number';
  if (!row.amount) return 'Amount likho';
  return null;
}

function makeCrud(collection, pick, validate, toPublic) {
  return {
    async list(db) {
      const rows = await db.collection(collection).find().sort({ id: 1 }).toArray();
      return rows.map(toPublic);
    },
    async add(db, body) {
      const row = pick(body);
      const err = validate(row);
      if (err) return { status: 400, json: { ok: false, error: err } };
      const id = await nextId(db, collection);
      const saved = { id, ...row };
      await db.collection(collection).insertOne(saved);
      return { status: 200, json: { ok: true, row: toPublic(saved) } };
    },
    async update(db, idRaw, body) {
      const id = Number.parseInt(String(idRaw), 10);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      const existing = await db.collection(collection).findOne({ id });
      if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      const row = pick({ ...toPublic(existing), ...body });
      const err = validate(row);
      if (err) return { status: 400, json: { ok: false, error: err } };
      const saved = { ...row, id };
      await db.collection(collection).updateOne({ id }, { $set: saved });
      return { status: 200, json: { ok: true, row: toPublic(saved) } };
    },
    async remove(db, idRaw) {
      const id = Number.parseInt(String(idRaw), 10);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      const result = await db.collection(collection).deleteOne({ id });
      if (!result.deletedCount) {
        return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      }
      return { status: 200, json: { ok: true } };
    },
  };
}

const cbc = makeCrud('cbc', pickCbc, validateCbc, publicCbc);
const ctopup = makeCrud('ctopup', pickCtopup, validateCtopup, publicCtopup);

module.exports = { cbc, ctopup };
