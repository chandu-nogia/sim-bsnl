'use strict';

const { moneyNumber, moneyText, parseAmount } = require('./password');
const { withAlive } = require('./alive');
const { dateKeyOf, applyDateRange, sortSpec } = require('./dates');
const { khatuLocation, khatuQuery } = require('./site');
const { logActivity } = require('./activity');
const { nextId } = require('./ids');
const { mongoListQuery, applyTextSearch } = require('./rbac');

function roundMoney(n) {
  return moneyNumber(n);
}

function moneyExpr(field, numField) {
  return {
    $convert: {
      input: { $ifNull: [`$${numField}`, `$${field}`] },
      to: 'double',
      onError: 0,
      onNull: 0,
    },
  };
}

async function moneySum(db, collection, locQ) {
  const rows = await db.collection(collection).aggregate([
    { $match: withAlive(locQ) },
    {
      $group: {
        _id: null,
        amount: { $sum: moneyExpr('amount', 'amountNum') },
        commission: { $sum: moneyExpr('commission', 'commissionNum') },
      },
    },
  ]).toArray();
  const r = rows[0] || {};
  return {
    amount: roundMoney(r.amount),
    commission: roundMoney(r.commission),
  };
}

async function creditSum(db, locQ) {
  const rows = await db.collection('wallet_txns').aggregate([
    { $match: withAlive({ ...locQ, transactionType: 'CREDIT' }) },
    { $group: { _id: null, amount: { $sum: moneyExpr('amount', 'amountNum') } } },
  ]).toArray();
  return roundMoney(rows[0]?.amount);
}

function remainingOf(wallet, amount, commission) {
  return roundMoney(wallet - amount + commission);
}

function publicTxn(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    txnId: row.txnId || `WLT-${String(id).padStart(6, '0')}`,
    transactionId: row.txnId || `WLT-${String(id).padStart(6, '0')}`,
    amount: row.amount || moneyText(row.amountNum),
    amountNum: moneyNumber(row.amountNum ?? row.amount),
    transactionType: row.transactionType || 'CREDIT',
    date: row.date || '',
    dateKey: row.dateKey || dateKeyOf(row.date),
    remark: row.remark || row.note || '',
    note: row.remark || row.note || '',
    createdBy: row.createdBy || '',
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
  };
}

async function snapshot(db) {
  const { snapshotBoth } = require('./service_wallet');
  const both = await snapshotBoth(db);
  return {
    ...both,
    cbcNet: remainingOf(0, both.cbcAmount, both.cbcCommission),
    ctopupNet: remainingOf(0, both.ctopupAmount, both.ctopupCommission),
  };
}

async function projectedRemaining(db, { extraCredit = 0, extraUsed = 0, extraCommission = 0 } = {}) {
  const snap = await snapshot(db);
  return remainingOf(
    snap.walletAmount + extraCredit,
    snap.combinedAmount + extraUsed,
    snap.combinedCommission + extraCommission,
  );
}

async function assertNotNegative(db, delta, message) {
  const next = await projectedRemaining(db, delta);
  if (next < 0) {
    return {
      status: 400,
      json: {
        ok: false,
        error: message || `Is change se wallet ₹${moneyText(next)} ho jayega. Pehle amount add karo ya amount kam karo.`,
        remaining: next,
      },
    };
  }
  return null;
}

async function recomputeBalances(db) {
  const snap = await snapshot(db);
  return snap.remainingBalance;
}

async function ensureOpeningCredit(db) {
  const loc = await khatuLocation(db);
  if (!loc) return;
  const locQ = khatuQuery(loc);
  const n = await db.collection('wallet_txns').countDocuments(withAlive(locQ));
  if (n > 0) return;
  const old = moneyNumber(loc.walletAmountNum ?? loc.walletAmount);
  if (old <= 0) return;
  const id = await nextId(db, 'wallet_txns');
  const now = new Date().toISOString();
  const date = now.slice(0, 10);
  await db.collection('wallet_txns').insertOne({
    id,
    txnId: `WLT-${String(id).padStart(6, '0')}`,
    amount: moneyText(old),
    amountNum: old,
    transactionType: 'CREDIT',
    date,
    dateKey: date,
    remark: 'Opening balance (previous wallet)',
    locationId: Number(loc.id) || 1,
    locationName: loc.name || 'Khatushyamji',
    createdBy: 'system',
    createdAt: now,
    updatedAt: now,
  });
}

async function listTransactions(db, scope = {}) {
  let q = withAlive(mongoListQuery(scope));
  q = applyTextSearch(q, ['txnId', 'remark', 'note', 'createdBy'], scope.q);
  q = applyDateRange(q, scope.from, scope.to);
  const typ = String(scope.txnType || scope.type || '').trim().toUpperCase();
  if (typ && typ !== 'ALL') q.transactionType = typ;
  const min = String(scope.minAmount ?? '').trim();
  const max = String(scope.maxAmount ?? '').trim();
  if (min || max) {
    q.amountNum = {};
    if (min) q.amountNum.$gte = moneyNumber(min);
    if (max) q.amountNum.$lte = moneyNumber(max);
  }
  const page = Math.max(1, Number(scope.page) || 1);
  const limit = Math.min(200, Math.max(20, Number(scope.limit) || 50));
  const skip = (page - 1) * limit;
  const col = db.collection('wallet_txns');
  const total = await col.countDocuments(q);
  const rows = await col.find(q).sort(sortSpec({ ...scope, sort: scope.sort || 'date' })).skip(skip).limit(limit).toArray();
  const snap = await snapshot(db);
  return {
    status: 200,
    json: {
      ok: true,
      rows: rows.map(publicTxn),
      total,
      page,
      limit,
      ...snap,
    },
  };
}

function pickCredit(body) {
  const b = body && typeof body === 'object' ? body : {};
  const parsed = parseAmount(b.amount, { required: true, allowZero: false });
  if (!parsed.ok) return { error: parsed.error };
  const date = String(b.date ?? '').trim() || new Date().toISOString().slice(0, 10);
  return {
    row: {
      amount: parsed.text,
      amountNum: parsed.value,
      transactionType: 'CREDIT',
      date,
      dateKey: dateKeyOf(date) || date.slice(0, 10),
      remark: String(b.remark ?? b.note ?? '').trim(),
    },
  };
}

async function addTransaction(db, body, meta) {
  const { addMoney } = require('./service_wallet');
  const service = String(body?.serviceType || body?.service || 'CBP');
  return addMoney(db, service, body, meta);
}

async function updateTransaction(db, idRaw, body, meta) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const existing = await db.collection('wallet_txns').findOne(withAlive({ id }));
  if (!existing) return { status: 404, json: { ok: false, error: 'Transaction nahi mili' } };
  const picked = pickCredit({ ...publicTxn(existing), ...body });
  if (picked.error) return { status: 400, json: { ok: false, error: picked.error } };
  const blocked = await assertNotNegative(db, {
    extraCredit: picked.row.amountNum - moneyNumber(existing.amountNum ?? existing.amount),
  }, 'Edit ke baad wallet balance negative ho jayega kyunki CBP/CTOPUP amount already use ho chuka hai.');
  if (blocked) return blocked;
  const saved = {
    ...picked.row,
    updatedAt: new Date().toISOString(),
  };
  await db.collection('wallet_txns').updateOne({ _id: existing._id }, { $set: saved });
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'update',
    section: 'wallet',
    locationId: existing.locationId,
    locationName: existing.locationName,
    recordId: id,
    detail: `${meta.name || meta.email} edited wallet ${existing.txnId}: ₹${moneyText(existing.amountNum)} → ₹${saved.amount}`,
  });
  await recomputeBalances(db);
  const fresh = await db.collection('wallet_txns').findOne({ id });
  return { status: 200, json: { ok: true, row: publicTxn(fresh || { ...existing, ...saved }), ...(await snapshot(db)) } };
}

async function removeTransaction(db, idRaw, meta) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const existing = await db.collection('wallet_txns').findOne(withAlive({ id }));
  if (!existing) return { status: 404, json: { ok: false, error: 'Transaction nahi mili' } };
  const blocked = await assertNotNegative(db, {
    extraCredit: -moneyNumber(existing.amountNum ?? existing.amount),
  }, 'Delete ke baad wallet balance negative ho jayega. Pehle CBP/CTOPUP amount adjust karo.');
  if (blocked) return blocked;
  await db.collection('wallet_txns').updateOne(
    { _id: existing._id },
    { $set: { deletedAt: new Date().toISOString(), deletedBy: meta.email || '', updatedAt: new Date().toISOString() } },
  );
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'delete',
    section: 'wallet',
    locationId: existing.locationId,
    locationName: existing.locationName,
    recordId: id,
    detail: `${meta.name || meta.email} deleted wallet ${existing.txnId} ₹${moneyText(existing.amountNum)}`,
  });
  await recomputeBalances(db);
  return { status: 200, json: { ok: true, ...(await snapshot(db)) } };
}

async function setWallet(db, body, meta) {
  return addTransaction(db, body, meta);
}

async function getWallet(db) {
  const snap = await snapshot(db);
  return { status: 200, json: { ok: true, ...snap } };
}

module.exports = {
  snapshot,
  setWallet,
  getWallet,
  recomputeBalances,
  remainingOf,
  roundMoney,
  listTransactions,
  addTransaction,
  updateTransaction,
  removeTransaction,
  ensureOpeningCredit,
  assertNotNegative,
  publicTxn,
};
