'use strict';

const { nextId } = require('./ids');
const { logActivity } = require('./activity');
const { mongoListQuery, applyTextSearch } = require('./rbac');
const { locationMatchQuery } = require('./location_resolve');
const { withAlive } = require('./alive');
const { dateKeyOf, applyDateRange, sortSpec } = require('./dates');
const { moneyNumber } = require('./password');
const { recomputeBalances, snapshot } = require('./wallet');

function moneyFields(b) {
  const amount = String(b.amount ?? '').trim();
  const commission = String(b.commission ?? b.commition ?? b.commision ?? '').trim();
  const balance = String(b.balance ?? '').trim();
  return {
    amount,
    amountNum: moneyNumber(amount),
    commission,
    commissionNum: moneyNumber(commission),
    balance,
    balanceNum: moneyNumber(balance),
  };
}

function publicCbc(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    date: row.date || '',
    dateKey: row.dateKey || dateKeyOf(row.date),
    name: row.name || '',
    mobile: row.mobile || '',
    landline: row.landline || '',
    amount: row.amount || '',
    amountNum: moneyNumber(row.amountNum ?? row.amount),
    commission: row.commission || '',
    commissionNum: moneyNumber(row.commissionNum ?? row.commission),
    balance: row.balance || '',
    balanceNum: moneyNumber(row.balanceNum ?? row.balance),
    transactionId: row.transactionId || '',
    note: row.note || '',
    createdBy: row.createdBy || '',
    employeeId: row.employeeId ? Number(row.employeeId) : null,
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
  };
}

function pickCbc(body) {
  const b = body && typeof body === 'object' ? body : {};
  const date = String(b.date ?? '').trim();
  return {
    date,
    dateKey: dateKeyOf(date),
    name: String(b.name ?? '').trim(),
    mobile: String(b.mobile ?? '').trim(),
    landline: String(b.landline ?? '').trim(),
    ...moneyFields(b),
    transactionId: String(b.transactionId ?? b.txnId ?? '').trim(),
    note: String(b.note ?? b.remarks ?? '').trim(),
  };
}

function validateCbc(_row) {
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
    dateKey: row.dateKey || dateKeyOf(row.date),
    name: row.name || '',
    number: row.number || '',
    amount: row.amount || '',
    amountNum: moneyNumber(row.amountNum ?? row.amount),
    commission: row.commission || '',
    commissionNum: moneyNumber(row.commissionNum ?? row.commission),
    balance: row.balance || '',
    balanceNum: moneyNumber(row.balanceNum ?? row.balance),
    status: row.status || 'Pending',
    transactionId: row.transactionId || '',
    note: row.note || '',
    createdBy: row.createdBy || '',
    employeeId: row.employeeId ? Number(row.employeeId) : null,
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
  };
}

function pickCtopup(body) {
  const b = body && typeof body === 'object' ? body : {};
  const date = String(b.date ?? '').trim();
  return {
    date,
    dateKey: dateKeyOf(date),
    name: String(b.name ?? '').trim(),
    number: String(b.number ?? b.mobile ?? '').trim(),
    ...moneyFields(b),
    status: String(b.status ?? b.paymentStatus ?? 'Pending').trim() || 'Pending',
    transactionId: String(b.transactionId ?? b.txnId ?? b.reference ?? '').trim(),
    note: String(b.note ?? b.remarks ?? '').trim(),
  };
}

function validateCtopup(_row) {
  return null;
}

function actorLabel(meta) {
  return meta.name || meta.email || 'Staff';
}

function makeCrud(collection, pick, validate, toPublic, section) {
  return {
    async list(db, scope = {}) {
      let q = withAlive(mongoListQuery(scope));
      q = applyTextSearch(q, ['name', 'mobile', 'number', 'transactionId', 'note'], scope.q);
      q = applyDateRange(q, scope.from, scope.to);
      const status = String(scope.status || '').trim();
      if (status) q.status = status;
      const page = Math.max(1, Number(scope.page) || 1);
      const limit = Math.min(500, Math.max(20, Number(scope.limit) || 200));
      const skip = (page - 1) * limit;
      const col = db.collection(collection);
      const total = await col.countDocuments(q);
      const rows = await col.find(q).sort(sortSpec(scope)).skip(skip).limit(limit).toArray();
      const snap = await snapshot(db);
      return {
        rows: rows.map(toPublic),
        total,
        page,
        limit,
        walletAmount: snap.walletAmount,
        remainingBalance: snap.remainingBalance,
      };
    },
    async add(db, body, meta) {
      const row = pick(body);
      const err = validate(row);
      if (err) return { status: 400, json: { ok: false, error: err } };
      if (row.transactionId && body?.force !== true) {
        const dup = await db.collection(collection).findOne(withAlive({
          locationId: Number(meta.locationId),
          transactionId: row.transactionId,
        }));
        if (dup) {
          return {
            status: 409,
            json: { ok: false, error: 'Is location mein ye Transaction ID pehle se hai', duplicate: true },
          };
        }
      }
      const id = await nextId(db, collection);
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
      await db.collection(collection).insertOne(saved);
      const moneyBit = row.amount ? ` of ₹${row.amount}` : '';
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        name: meta.name,
        action: 'add',
        section,
        locationId: saved.locationId,
        locationName: saved.locationName,
        detail: `${actorLabel(meta)} added ${section === 'ctopup' ? 'C-TopUp transaction' : 'CBP record'}${moneyBit} in ${saved.locationName}`,
      });
      await recomputeBalances(db);
      const fresh = await db.collection(collection).findOne({ id });
      return { status: 200, json: { ok: true, row: toPublic(fresh || saved) } };
    },
    async update(db, idRaw, body, meta, assertRow) {
      const id = Number.parseInt(String(idRaw), 10);
      const locId = Number(meta.locationId);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      if (!locId) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
      const existing = await db.collection(collection).findOne({ id, ...locationMatchQuery(locId) });
      if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      const blocked = await assertRow(existing);
      if (blocked) return blocked;
      const row = pick({ ...toPublic(existing), ...body });
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
      await db.collection(collection).updateOne({ _id: existing._id }, { $set: saved });
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        name: meta.name,
        action: 'update',
        section,
        locationId: saved.locationId,
        locationName: saved.locationName,
        detail: `${actorLabel(meta)} updated ${section === 'ctopup' ? 'C-TopUp' : 'CBP'} record in ${saved.locationName}`,
      });
      await recomputeBalances(db);
      const fresh = await db.collection(collection).findOne({ id });
      return { status: 200, json: { ok: true, row: toPublic(fresh || saved) } };
    },
    async remove(db, idRaw, meta, assertRow) {
      const id = Number.parseInt(String(idRaw), 10);
      const locId = Number(meta.locationId);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      if (!locId) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
      const existing = await db.collection(collection).findOne({ id, ...locationMatchQuery(locId) });
      if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      const blocked = await assertRow(existing);
      if (blocked) return blocked;
      await db.collection(collection).updateOne(
        { _id: existing._id },
        { $set: { deletedAt: new Date().toISOString(), deletedBy: meta.email || '', updatedAt: new Date().toISOString() } },
      );
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        name: meta.name,
        action: 'delete',
        section,
        locationId: existing.locationId,
        locationName: existing.locationName || '',
        detail: `${actorLabel(meta)} deleted ${section === 'ctopup' ? 'C-TopUp' : 'CBP'} record in ${existing.locationName || ''}`,
      });
      await recomputeBalances(db);
      return { status: 200, json: { ok: true } };
    },
  };
}

const cbc = makeCrud('cbc', pickCbc, validateCbc, publicCbc, 'cbc');
const ctopup = makeCrud('ctopup', pickCtopup, validateCtopup, publicCtopup, 'ctopup');

module.exports = { cbc, ctopup };
