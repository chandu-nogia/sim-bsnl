'use strict';

const { nextId } = require('./ids');
const { logActivity } = require('./activity');
const { withAlive } = require('./alive');
const { khatuLocation, khatuQuery } = require('./site');
const { dateKeyOf, applyDateRange, sortSpec } = require('./dates');
const { mongoListQuery } = require('./rbac');
const {
  toPaise,
  requirePositivePaise,
  fromPaise,
  paiseOf,
  rupeeNum,
  validateUsage,
  normalizeService,
} = require('./money');

function publicWallet(row) {
  const current = Number(row.currentBalancePaise) || 0;
  return {
    id: Number(row.id) || null,
    serviceType: row.serviceType,
    currentBalance: fromPaise(current),
    currentBalanceNum: rupeeNum(current),
    currentBalancePaise: current,
    totalCredits: fromPaise(row.totalCreditsPaise),
    totalCreditsNum: rupeeNum(row.totalCreditsPaise),
    totalCreditsPaise: Number(row.totalCreditsPaise) || 0,
    totalDebits: fromPaise(row.totalDebitsPaise),
    totalDebitsNum: rupeeNum(row.totalDebitsPaise),
    totalDebitsPaise: Number(row.totalDebitsPaise) || 0,
    totalTransactionAmount: fromPaise(row.totalTransactionAmountPaise),
    totalTransactionAmountNum: rupeeNum(row.totalTransactionAmountPaise),
    totalTransactionAmountPaise: Number(row.totalTransactionAmountPaise) || 0,
    totalCommission: fromPaise(row.totalCommissionPaise),
    totalCommissionNum: rupeeNum(row.totalCommissionPaise),
    totalCommissionPaise: Number(row.totalCommissionPaise) || 0,
    remainingBalance: rupeeNum(current),
    totalAdded: rupeeNum(row.totalCreditsPaise),
    totalUsed: rupeeNum(row.totalTransactionAmountPaise),
    updatedAt: row.updatedAt || '',
  };
}

function publicLedger(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    walletId: row.walletId || null,
    serviceType: row.serviceType || '',
    txnId: row.txnId || `LED-${String(id).padStart(6, '0')}`,
    transactionId: row.txnId || '',
    transactionType: row.transactionType || '',
    amount: fromPaise(row.amountPaise),
    amountNum: rupeeNum(row.amountPaise),
    previousBalance: fromPaise(row.previousBalancePaise),
    newBalance: fromPaise(row.newBalancePaise),
    commission: fromPaise(row.commissionPaise || 0),
    relatedTransactionId: row.relatedTransactionId || '',
    referenceId: row.referenceId || '',
    description: row.description || row.remark || '',
    remark: row.description || row.remark || '',
    note: row.description || row.remark || '',
    createdBy: row.createdBy || '',
    createdAt: row.createdAt || '',
    date: row.date || (row.createdAt || '').slice(0, 10),
  };
}

async function locOf(db) {
  const loc = await khatuLocation(db);
  return {
    loc,
    locationId: Number(loc?.id) || 1,
    locationName: loc?.name || 'Khatushyamji',
    locQ: loc ? khatuQuery(loc) : { locationId: 1 },
  };
}

async function getWalletDoc(db, serviceType) {
  const service = normalizeService(serviceType);
  if (!service) return null;
  const { locationId } = await locOf(db);
  return db.collection('wallets').findOne({ serviceType: service, locationId });
}

async function ensureWallet(db, serviceType) {
  const service = normalizeService(serviceType);
  if (!service) throw new Error('Service type CBP ya CTOPUP hona chahiye');
  const { locationId, locationName } = await locOf(db);
  let row = await db.collection('wallets').findOne({ serviceType: service, locationId });
  if (row) return row;
  const id = await nextId(db, 'wallets');
  const now = new Date().toISOString();
  row = {
    id,
    serviceType: service,
    locationId,
    locationName,
    currentBalancePaise: 0,
    totalCreditsPaise: 0,
    totalDebitsPaise: 0,
    totalTransactionAmountPaise: 0,
    totalCommissionPaise: 0,
    createdAt: now,
    updatedAt: now,
  };
  await db.collection('wallets').insertOne(row);
  return row;
}

async function insertLedger(db, wallet, fields) {
  const id = await nextId(db, 'wallet_ledger');
  const now = new Date().toISOString();
  const date = fields.date || now.slice(0, 10);
  const saved = {
    id,
    txnId: `LED-${String(id).padStart(6, '0')}`,
    walletId: wallet.id,
    serviceType: wallet.serviceType,
    locationId: wallet.locationId,
    locationName: wallet.locationName,
    date,
    dateKey: dateKeyOf(date) || date,
    createdAt: now,
    updatedAt: now,
    ...fields,
  };
  await db.collection('wallet_ledger').insertOne(saved);
  return saved;
}

async function casWriteWallet(db, wallet, previousPaise, patch) {
  const nextPatch = { ...patch, updatedAt: new Date().toISOString() };
  const filter = wallet._id !== undefined
    ? { _id: wallet._id, currentBalancePaise: previousPaise }
    : { id: wallet.id, serviceType: wallet.serviceType, currentBalancePaise: previousPaise };
  const result = await db.collection('wallets').findOneAndUpdate(
    filter,
    { $set: nextPatch },
    { returnDocument: 'after', upsert: false },
  );
  const saved = result && (Object.prototype.hasOwnProperty.call(result, 'value') ? result.value : result);
  if (!saved || saved.currentBalancePaise === undefined) {
    return null;
  }
  return saved;
}

function conflict() {
  return { status: 409, json: { ok: false, error: 'Wallet abhi update ho raha hai. Dobara try karo.' } };
}

async function addMoney(db, serviceType, body, meta) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  const parsed = requirePositivePaise(body?.amount, 'Amount');
  if (!parsed.ok) return { status: 400, json: { ok: false, error: parsed.error } };
  const wallet = await ensureWallet(db, service);
  const previous = Number(wallet.currentBalancePaise) || 0;
  const next = previous + parsed.paise;
  const now = new Date().toISOString();
  const date = String(body?.date || '').trim() || now.slice(0, 10);
  const saved = await casWriteWallet(db, wallet, previous, {
    currentBalancePaise: next,
    totalCreditsPaise: (Number(wallet.totalCreditsPaise) || 0) + parsed.paise,
  });
  if (!saved) return conflict();
  const ledger = await insertLedger(db, wallet, {
    transactionType: 'CREDIT',
    amountPaise: parsed.paise,
    previousBalancePaise: previous,
    newBalancePaise: next,
    commissionPaise: 0,
    description: String(body?.remark || body?.note || 'Add money').trim(),
    referenceId: String(body?.referenceId || body?.reference || '').trim(),
    source: String(body?.source || 'manual').trim() || 'manual',
    createdBy: meta.email || '',
    date,
  });
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'add',
    section: 'wallet',
    locationId: wallet.locationId,
    locationName: wallet.locationName,
    recordId: ledger.id,
    detail: `${meta.name || meta.email} added ₹${parsed.text} to ${service} wallet (${fromPaise(previous)} → ${fromPaise(next)})`,
  });
  return { status: 200, json: { ok: true, wallet: publicWallet(saved), ledger: publicLedger(ledger) } };
}

async function withdraw(db, serviceType, body, meta) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  const parsed = requirePositivePaise(body?.amount, 'Amount');
  if (!parsed.ok) return { status: 400, json: { ok: false, error: parsed.error } };
  const wallet = await ensureWallet(db, service);
  const previous = Number(wallet.currentBalancePaise) || 0;
  if (parsed.paise > previous) {
    return { status: 400, json: { ok: false, error: `${service} wallet mein itna balance nahi hai (available ₹${fromPaise(previous)})` } };
  }
  const next = previous - parsed.paise;
  const now = new Date().toISOString();
  const date = String(body?.date || '').trim() || now.slice(0, 10);
  const saved = await casWriteWallet(db, wallet, previous, {
    currentBalancePaise: next,
    totalDebitsPaise: (Number(wallet.totalDebitsPaise) || 0) + parsed.paise,
  });
  if (!saved) return conflict();
  const ledger = await insertLedger(db, wallet, {
    transactionType: 'DEBIT',
    amountPaise: parsed.paise,
    previousBalancePaise: previous,
    newBalancePaise: next,
    commissionPaise: 0,
    description: String(body?.reason || body?.remark || body?.note || 'Withdraw').trim(),
    referenceId: String(body?.referenceId || '').trim(),
    createdBy: meta.email || '',
    date,
  });
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'update',
    section: 'wallet',
    locationId: wallet.locationId,
    locationName: wallet.locationName,
    recordId: ledger.id,
    detail: `${meta.name || meta.email} withdrew ₹${parsed.text} from ${service} wallet (${fromPaise(previous)} → ${fromPaise(next)})`,
  });
  return { status: 200, json: { ok: true, wallet: publicWallet(saved), ledger: publicLedger(ledger) } };
}

function isFailedStatus(status) {
  return String(status || '').toLowerCase() === 'failed';
}

async function applyUsage(db, serviceType, body, meta) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  if (isFailedStatus(body?.status)) {
    return { status: 200, json: { ok: true, skipped: true, reason: 'Failed transaction wallet nahi badalti' } };
  }
  const amount = requirePositivePaise(body?.amount, 'Transaction amount');
  if (!amount.ok) return { status: 400, json: { ok: false, error: amount.error } };
  const wallet = await ensureWallet(db, service);
  const previous = Number(wallet.currentBalancePaise) || 0;
  const actualRaw = body?.actualBalance ?? body?.balance ?? body?.actual;
  const actualEmpty = String(actualRaw ?? '').trim() === '';
  let actualPaise = previous - amount.paise;
  if (!actualEmpty) {
    const actual = toPaise(actualRaw);
    if (!actual.ok) return { status: 400, json: { ok: false, error: 'Balance (jo khate mein bacha) number mein likho' } };
    actualPaise = actual.paise;
  }
  const checked = validateUsage({ previousPaise: previous, amountPaise: amount.paise, actualPaise });
  if (!checked.ok) return { status: 400, json: { ok: false, error: checked.error, calc: checked.calc } };
  const calc = checked.calc;
  const ref = String(body?.transactionId || body?.referenceNumber || body?.referenceId || '').trim();
  if (ref) {
    const dup = await db.collection('wallet_ledger').findOne(withAlive({
      serviceType: service,
      locationId: wallet.locationId,
      relatedTransactionId: ref,
      transactionType: 'USAGE',
    }));
    if (dup) {
      return { status: 409, json: { ok: false, error: 'Is reference ki transaction pehle se wallet mein hai', duplicate: true } };
    }
  }
  const saved = await casWriteWallet(db, wallet, previous, {
    currentBalancePaise: calc.actualPaise,
    totalDebitsPaise: (Number(wallet.totalDebitsPaise) || 0) + calc.amountPaise,
    totalTransactionAmountPaise: (Number(wallet.totalTransactionAmountPaise) || 0) + calc.amountPaise,
    totalCommissionPaise: (Number(wallet.totalCommissionPaise) || 0) + calc.commissionPaise,
  });
  if (!saved) return conflict();
  const ledger = await insertLedger(db, wallet, {
    transactionType: 'USAGE',
    amountPaise: calc.amountPaise,
    previousBalancePaise: calc.previousPaise,
    newBalancePaise: calc.actualPaise,
    expectedBalancePaise: calc.expectedPaise,
    commissionPaise: calc.commissionPaise,
    relatedTransactionId: ref || String(body?.recordId || ''),
    referenceId: ref,
    description: `${service} transaction ₹${calc.amount}`,
    createdBy: meta.email || '',
    date: String(body?.date || '').trim() || new Date().toISOString().slice(0, 10),
  });
  return {
    status: 200,
    json: {
      ok: true,
      wallet: publicWallet(saved),
      ledger: publicLedger(ledger),
      calc,
    },
  };
}

async function reverseUsage(db, serviceType, existing, meta) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type galat hai' } };
  if (existing.walletApplied === false || existing.transactionStatus === 'FAILED' || isFailedStatus(existing.status)) {
    return { status: 200, json: { ok: true, skipped: true } };
  }
  if (existing.transactionStatus === 'REVERSED') {
    return { status: 400, json: { ok: false, error: 'Ye transaction pehle reverse ho chuki hai' } };
  }
  const wallet = await ensureWallet(db, service);
  const amount = Number(existing.amountPaise ?? paiseOf(existing.amountNum ?? existing.amount));
  const commission = Number(existing.commissionPaise ?? paiseOf(existing.commissionNum ?? existing.commission));
  const previous = Number(wallet.currentBalancePaise) || 0;
  const next = previous + amount - commission;
  const saved = await casWriteWallet(db, wallet, previous, {
    currentBalancePaise: next,
    totalDebitsPaise: Math.max(0, (Number(wallet.totalDebitsPaise) || 0) - amount),
    totalTransactionAmountPaise: Math.max(0, (Number(wallet.totalTransactionAmountPaise) || 0) - amount),
    totalCommissionPaise: Math.max(0, (Number(wallet.totalCommissionPaise) || 0) - commission),
  });
  if (!saved) return conflict();
  const ledger = await insertLedger(db, wallet, {
    transactionType: 'REVERSAL',
    amountPaise: amount,
    previousBalancePaise: previous,
    newBalancePaise: next,
    expectedBalancePaise: previous + amount,
    commissionPaise: -commission,
    relatedTransactionId: String(existing.transactionId || existing.id || ''),
    referenceId: `REV-${existing.id}`,
    description: `Reversal of ${service} txn ${existing.transactionId || existing.id}`,
    createdBy: meta.email || '',
  });
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'update',
    section: 'wallet',
    locationId: wallet.locationId,
    locationName: wallet.locationName,
    recordId: existing.id,
    detail: `${meta.name || meta.email} reversed ${service} txn ${existing.id} ₹${fromPaise(amount)}`,
  });
  return { status: 200, json: { ok: true, wallet: publicWallet(saved), ledger: publicLedger(ledger) } };
}

async function getService(db, serviceType) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  const wallet = await ensureWallet(db, service);
  return { status: 200, json: { ok: true, ...publicWallet(wallet) } };
}

async function listLedger(db, serviceType, scope = {}) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  let q = withAlive({ ...mongoListQuery(scope), serviceType: service });
  const { applyTextSearch: search } = require('./rbac');
  q = search(q, ['txnId', 'description', 'remark', 'referenceId', 'relatedTransactionId', 'createdBy'], scope.q);
  q = applyDateRange(q, scope.from, scope.to);
  const typ = String(scope.txnType || scope.type || '').trim().toUpperCase();
  if (typ && typ !== 'ALL') q.transactionType = typ;
  const page = Math.max(1, Number(scope.page) || 1);
  const limit = Math.min(200, Math.max(20, Number(scope.limit) || 50));
  const skip = (page - 1) * limit;
  const col = db.collection('wallet_ledger');
  const total = await col.countDocuments(q);
  const rows = await col.find(q).sort(sortSpec({ ...scope, sort: scope.sort || 'date' })).skip(skip).limit(limit).toArray();
  const wallet = await ensureWallet(db, service);
  return {
    status: 200,
    json: {
      ok: true,
      rows: rows.map(publicLedger),
      total,
      page,
      limit,
      ...publicWallet(wallet),
    },
  };
}

async function listCommission(db, serviceType, scope = {}) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  let q = withAlive({
    ...mongoListQuery(scope),
    serviceType: service,
    transactionType: { $in: ['USAGE', 'REVERSAL'] },
  });
  q = applyDateRange(q, scope.from, scope.to);
  const { applyTextSearch: search } = require('./rbac');
  q = search(q, ['txnId', 'relatedTransactionId', 'referenceId', 'description'], scope.q);
  const page = Math.max(1, Number(scope.page) || 1);
  const limit = Math.min(200, Math.max(20, Number(scope.limit) || 50));
  const skip = (page - 1) * limit;
  const col = db.collection('wallet_ledger');
  const total = await col.countDocuments(q);
  const rows = await col.find(q).sort({ id: -1 }).skip(skip).limit(limit).toArray();
  const wallet = await ensureWallet(db, service);
  return {
    status: 200,
    json: {
      ok: true,
      rows: rows.map((r) => ({
        ...publicLedger(r),
        rechargeAmount: fromPaise(r.amountPaise),
        expectedBalance: fromPaise(r.expectedBalancePaise ?? ((Number(r.previousBalancePaise) || 0) - (Number(r.amountPaise) || 0))),
        actualBalance: fromPaise(r.newBalancePaise),
        status: r.transactionType === 'REVERSAL' ? 'REVERSED' : 'SUCCESS',
        service: r.serviceType,
      })),
      total,
      page,
      limit,
      ...publicWallet(wallet),
      totalCommission: publicWallet(wallet).totalCommission,
    },
  };
}

async function periodCommission(db, serviceType, from, to) {
  const service = normalizeService(serviceType);
  let q = withAlive({
    serviceType: service,
    transactionType: { $in: ['USAGE', 'REVERSAL'] },
  });
  q = applyDateRange(q, from, to);
  const rows = await db.collection('wallet_ledger').find(q).project({ commissionPaise: 1 }).toArray();
  let paise = 0;
  for (const r of rows) paise += Number(r.commissionPaise) || 0;
  return { paise, amount: fromPaise(paise), amountNum: rupeeNum(paise) };
}

async function listServiceTransactions(db, serviceType, scope = {}) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  const collection = service === 'CTOPUP' ? 'ctopup' : 'cbc';
  let q = withAlive(mongoListQuery(scope));
  const { applyTextSearch: search } = require('./rbac');
  q = search(q, ['name', 'mobile', 'number', 'transactionId', 'note', 'type', 'operator'], scope.q);
  q = applyDateRange(q, scope.from, scope.to);
  const page = Math.max(1, Number(scope.page) || 1);
  const limit = Math.min(200, Math.max(20, Number(scope.limit) || 50));
  const skip = (page - 1) * limit;
  const col = db.collection(collection);
  const total = await col.countDocuments(q);
  const rows = await col.find(q).sort(sortSpec({ ...scope, sort: scope.sort || 'date' })).skip(skip).limit(limit).toArray();
  const wallet = await ensureWallet(db, service);
  return {
    status: 200,
    json: {
      ok: true,
      rows,
      total,
      page,
      limit,
      ...publicWallet(wallet),
    },
  };
}

async function reverseByRef(db, serviceType, body, meta) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type galat hai' } };
  const collection = service === 'CTOPUP' ? 'ctopup' : 'cbc';
  const id = Number.parseInt(String(body?.id || body?.recordId || ''), 10);
  const ref = String(body?.transactionId || body?.referenceNumber || '').trim();
  let existing = null;
  if (id) existing = await db.collection(collection).findOne({ id });
  if (!existing && ref) {
    existing = await db.collection(collection).findOne(withAlive({ transactionId: ref }));
  }
  if (!existing) return { status: 404, json: { ok: false, error: 'Transaction nahi mili' } };
  const out = await reverseUsage(db, service, existing, meta);
  if (out.status !== 200) return out;
  if (!out.json.skipped) {
    await db.collection(collection).updateOne(
      { _id: existing._id },
      { $set: { transactionStatus: 'REVERSED', walletApplied: false, updatedAt: new Date().toISOString() } },
    );
  }
  return out;
}

async function snapshotBoth(db) {
  const cbp = publicWallet(await ensureWallet(db, 'CBP'));
  const top = publicWallet(await ensureWallet(db, 'CTOPUP'));
  return {
    cbp,
    ctopup: top,
    walletAmount: rupeeNum((cbp.currentBalancePaise || 0) + (top.currentBalancePaise || 0)),
    remainingBalance: rupeeNum((cbp.currentBalancePaise || 0) + (top.currentBalancePaise || 0)),
    totalAdded: rupeeNum((cbp.totalCreditsPaise || 0) + (top.totalCreditsPaise || 0)),
    totalUsed: rupeeNum((cbp.totalTransactionAmountPaise || 0) + (top.totalTransactionAmountPaise || 0)),
    combinedAmount: rupeeNum((cbp.totalTransactionAmountPaise || 0) + (top.totalTransactionAmountPaise || 0)),
    combinedCommission: rupeeNum((cbp.totalCommissionPaise || 0) + (top.totalCommissionPaise || 0)),
    cbcAmount: cbp.totalTransactionAmountNum,
    cbcCommission: cbp.totalCommissionNum,
    ctopupAmount: top.totalTransactionAmountNum,
    ctopupCommission: top.totalCommissionNum,
    cbpBalance: cbp.currentBalanceNum,
    ctopupBalance: top.currentBalanceNum,
  };
}

async function migrateLegacy(db) {
  await ensureWallet(db, 'CBP');
  await ensureWallet(db, 'CTOPUP');
  const cbp = await getWalletDoc(db, 'CBP');
  if (!cbp || (Number(cbp.currentBalancePaise) || 0) > 0 || (Number(cbp.totalCreditsPaise) || 0) > 0) return;
  const { locQ } = await locOf(db);
  const oldCredits = await db.collection('wallet_txns').find(withAlive({ ...locQ, transactionType: 'CREDIT' })).toArray();
  if (!oldCredits.length) return;
  const meta = { email: 'system', name: 'system', role: 'owner' };
  for (const row of oldCredits) {
    if (row.migratedToService) continue;
    const amount = row.amountPaise || paiseOf(row.amountNum ?? row.amount);
    if (amount <= 0) continue;
    await addMoney(db, 'CBP', { amount: fromPaise(amount), remark: row.remark || 'Migrated opening credit', date: row.date }, meta);
    await db.collection('wallet_txns').updateOne({ _id: row._id }, { $set: { migratedToService: 'CBP' } });
  }
}

module.exports = {
  ensureWallet,
  getWalletDoc,
  publicWallet,
  publicLedger,
  addMoney,
  withdraw,
  applyUsage,
  reverseUsage,
  reverseByRef,
  getService,
  listLedger,
  listCommission,
  listServiceTransactions,
  periodCommission,
  snapshotBoth,
  migrateLegacy,
  isFailedStatus,
};
