'use strict';

function publicRow(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
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
  };
}

function validate(row) {
  if (!row.name) return 'Naam likho';
  if (!/^\d{10}$/.test(row.mobile)) return '10 digit mobile';
  if (row.alt && !/^\d{10}$/.test(row.alt)) return 'Alternate number 10 digit';
  if (row.sim.length < 6) return 'SIM number likho';
  return null;
}

async function nextId(db) {
  const result = await db.collection('counters').findOneAndUpdate(
    { _id: 'sims' },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' },
  );
  const seq = result && (result.seq ?? result.value?.seq);
  return Number(seq) || 1;
}

async function listSims(db) {
  const rows = await db.collection('sims').find().sort({ id: 1 }).toArray();
  return rows.map(publicRow);
}

async function addSim(db, body) {
  const row = pickBody(body);
  const err = validate(row);
  if (err) return { status: 400, json: { ok: false, error: err } };
  if (!row.sno) {
    const last = await db.collection('sims').find().sort({ sno: -1 }).limit(1).next();
    row.sno = (last && Number(last.sno) ? Number(last.sno) : 0) + 1;
  }
  const id = await nextId(db);
  const saved = { id, ...row };
  await db.collection('sims').insertOne(saved);
  return { status: 200, json: { ok: true, row: publicRow(saved) } };
}

async function updateSim(db, idRaw, body) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const existing = await db.collection('sims').findOne({ id });
  if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
  const row = pickBody({ ...publicRow(existing), ...body });
  const err = validate(row);
  if (err) return { status: 400, json: { ok: false, error: err } };
  const saved = { ...row, id };
  await db.collection('sims').updateOne({ id }, { $set: saved });
  return { status: 200, json: { ok: true, row: publicRow(saved) } };
}

async function deleteSim(db, idRaw) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const result = await db.collection('sims').deleteOne({ id });
  if (!result.deletedCount) {
    return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
  }
  return { status: 200, json: { ok: true } };
}

module.exports = { publicRow, pickBody, validate, listSims, addSim, updateSim, deleteSim };
