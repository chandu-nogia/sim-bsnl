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
  resolveUsageCommission,
  usageApiFields,
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

function ledgerDisplayType(row) {
  const t = String(row.transactionType || '').toUpperCase();
  if (t === 'USAGE') return 'TRANSACTION';
  if (t === 'REVERSAL') return 'ADJUSTMENT';
  return t || 'TRANSACTION';
}

function ledgerSource(row) {
  if (row.source) return String(row.source).toUpperCase();
  const t = String(row.transactionType || '').toUpperCase();
  if (t === 'CREDIT') return 'MANUAL_DEPOSIT';
  if (t === 'REVERSAL') return 'REFUND';
  if (t === 'DEBIT') return 'ADJUSTMENT';
  return String(row.serviceType || 'CBP').toUpperCase();
}

function publicLedger(row) {
  const id = Number(row.id);
  const amountPaise = Number(row.amountPaise) || 0;
  const commissionPaise = Number(row.commissionPaise) || 0;
  const type = String(row.transactionType || '').toUpperCase();
  let netPaise = Number(row.netImpactPaise);
  if (!Number.isFinite(netPaise)) {
    if (type === 'CREDIT') netPaise = amountPaise;
    else if (type === 'DEBIT') netPaise = -amountPaise;
    else if (type === 'REVERSAL') netPaise = amountPaise - Math.abs(commissionPaise);
    else netPaise = -amountPaise + commissionPaise;
  }
  return {
    id,
    rowIndex: id,
    walletId: row.walletId || null,
    serviceType: row.serviceType || '',
    service: row.serviceType || '',
    txnId: row.txnId || `LED-${String(id).padStart(6, '0')}`,
    transactionId: row.txnId || '',
    transactionType: row.transactionType || '',
    type: ledgerDisplayType(row),
    source: ledgerSource(row),
    amount: fromPaise(amountPaise),
    amountNum: rupeeNum(amountPaise),
    previousBalance: fromPaise(row.previousBalancePaise),
    newBalance: fromPaise(row.newBalancePaise),
    balanceBefore: fromPaise(row.previousBalancePaise),
    balanceAfter: fromPaise(row.newBalancePaise),
    commission: fromPaise(commissionPaise),
    commissionNum: rupeeNum(commissionPaise),
    netImpact: fromPaise(netPaise),
    netImpactNum: rupeeNum(netPaise),
    relatedTransactionId: row.relatedTransactionId || '',
    referenceId: row.referenceId || row.relatedTransactionId || '',
    description: row.description || row.remark || '',
    remark: row.description || row.remark || '',
    note: row.description || row.remark || '',
    customerName: row.customerName || '',
    mobile: row.mobile || '',
    status: row.status || (type === 'REVERSAL' ? 'REVERSED' : 'SUCCESS'),
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
    source: 'MANUAL_DEPOSIT',
    status: 'SUCCESS',
    netImpactPaise: parsed.paise,
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
    source: 'ADJUSTMENT',
    status: 'SUCCESS',
    netImpactPaise: -parsed.paise,
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

function usagePayload(calc, { service, referenceId, wallet, ledger, duplicate }) {
  return {
    ok: true,
    ...usageApiFields(calc, { service, referenceId }),
    duplicate: Boolean(duplicate),
    wallet: wallet ? publicWallet(wallet) : undefined,
    ledger: ledger ? publicLedger(ledger) : undefined,
    calc,
  };
}

async function previewUsage(db, serviceType, body) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  const amount = requirePositivePaise(body?.amount, 'Transaction amount');
  if (!amount.ok) return { status: 400, json: { ok: false, error: amount.error } };
  const wallet = await ensureWallet(db, service);
  const previous = Number(wallet.currentBalancePaise) || 0;
  const resolved = resolveUsageCommission({
    previousPaise: previous,
    amountPaise: amount.paise,
    actualRaw: body?.actualBalance ?? body?.balance ?? body?.actual,
  });
  if (!resolved.ok) return { status: 400, json: { ok: false, error: resolved.error } };
  const checked = validateUsage({
    previousPaise: previous,
    amountPaise: amount.paise,
    commissionPaise: resolved.commissionPaise,
  });
  if (!checked.ok) {
    return { status: 400, json: { ok: false, error: checked.error, code: checked.code || '', calc: checked.calc } };
  }
  return {
    status: 200,
    json: {
      ok: true,
      ...usageApiFields(checked.calc, { service, referenceId: '' }),
      wallet: publicWallet(wallet),
      calc: checked.calc,
    },
  };
}

async function applyUsage(db, serviceType, body, meta = {}) {
  const service = normalizeService(serviceType);
  if (!service) return { status: 400, json: { ok: false, error: 'Service type CBP ya CTOPUP hona chahiye' } };
  if (isFailedStatus(body?.status)) {
    return { status: 200, json: { ok: true, skipped: true, success: false, reason: 'Failed transaction wallet nahi badalti' } };
  }
  const amount = requirePositivePaise(body?.amount, 'Transaction amount');
  if (!amount.ok) return { status: 400, json: { ok: false, error: amount.error } };
  const wallet = await ensureWallet(db, service);
  const previous = Number(wallet.currentBalancePaise) || 0;
  const resolved = resolveUsageCommission({
    previousPaise: previous,
    amountPaise: amount.paise,
    actualRaw: body?.actualBalance ?? body?.balance ?? body?.actual,
  });
  if (!resolved.ok) return { status: 400, json: { ok: false, error: resolved.error } };
  const checked = validateUsage({
    previousPaise: previous,
    amountPaise: amount.paise,
    commissionPaise: resolved.commissionPaise,
  });
  if (!checked.ok) {
    return { status: 400, json: { ok: false, error: checked.error, code: checked.code || '', calc: checked.calc } };
  }
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
      return {
        status: 409,
        json: {
          ok: false,
          success: false,
          duplicate: true,
          error: 'Is reference ki transaction pehle se wallet mein hai',
          amount: rupeeNum(calc.amountPaise),
          commission: rupeeNum(calc.commissionPaise),
          previousBalance: rupeeNum(wallet.currentBalancePaise),
          newBalance: rupeeNum(wallet.currentBalancePaise),
          referenceId: ref,
          service,
          wallet: publicWallet(wallet),
          ledger: publicLedger(dup),
        },
      };
    }
  }
  const saved = await casWriteWallet(db, wallet, previous, {
    currentBalancePaise: calc.newBalancePaise,
    totalDebitsPaise: (Number(wallet.totalDebitsPaise) || 0) + calc.amountPaise,
    totalTransactionAmountPaise: (Number(wallet.totalTransactionAmountPaise) || 0) + calc.amountPaise,
    totalCommissionPaise: (Number(wallet.totalCommissionPaise) || 0) + calc.commissionPaise,
  });
  if (!saved) return conflict();
  let ledger;
  try {
    ledger = await insertLedger(db, wallet, {
      transactionType: 'USAGE',
      amountPaise: calc.amountPaise,
      previousBalancePaise: calc.previousPaise,
      newBalancePaise: calc.newBalancePaise,
      expectedBalancePaise: calc.expectedPaise,
      commissionPaise: calc.commissionPaise,
      netImpactPaise: calc.netImpactPaise,
      relatedTransactionId: ref || String(body?.recordId || ''),
      referenceId: ref,
      source: service,
      status: 'SUCCESS',
      customerName: String(body?.name || body?.customerName || '').trim(),
      mobile: String(body?.mobile || body?.number || '').trim(),
      description: `${service} ₹${calc.amount} + commission ₹${calc.commission} = ${fromPaise(calc.netImpactPaise)}`,
      createdBy: meta.email || '',
      date: String(body?.date || '').trim() || new Date().toISOString().slice(0, 10),
    });
  } catch (e) {
    await casWriteWallet(db, saved, calc.newBalancePaise, {
      currentBalancePaise: previous,
      totalDebitsPaise: Number(wallet.totalDebitsPaise) || 0,
      totalTransactionAmountPaise: Number(wallet.totalTransactionAmountPaise) || 0,
      totalCommissionPaise: Number(wallet.totalCommissionPaise) || 0,
    });
    throw e;
  }
  await logActivity(db, {
    email: meta.email,
    role: meta.role,
    name: meta.name,
    action: 'add',
    section: 'wallet',
    locationId: wallet.locationId,
    locationName: wallet.locationName,
    recordId: ledger.id,
    ip: meta.ip || '',
    detail: `${meta.name || meta.email || 'system'} ${service} usage ₹${calc.amount} comm ₹${calc.commission} (${calc.previous} → ${calc.newBalance}) ref ${ref || ledger.id}`,
  });
  return {
    status: 200,
    json: usagePayload(calc, { service, referenceId: ref || String(ledger.id), wallet: saved, ledger }),
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
    source: 'REFUND',
    status: 'REVERSED',
    netImpactPaise: amount - commission,
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
  q = search(q, ['txnId', 'description', 'remark', 'referenceId', 'relatedTransactionId', 'createdBy', 'customerName', 'mobile'], scope.q);
  q = applyDateRange(q, scope.from, scope.to);
  const typ = String(scope.txnType || scope.type || '').trim().toUpperCase();
  if (typ && typ !== 'ALL') {
    if (typ === 'TRANSACTION') q.transactionType = 'USAGE';
    else if (typ === 'ADJUSTMENT') q.transactionType = { $in: ['REVERSAL', 'DEBIT'] };
    else if (typ === 'COMMISSION') q.transactionType = { $in: ['USAGE', 'REVERSAL'] };
    else q.transactionType = typ;
  }
  const source = String(scope.source || '').trim().toUpperCase();
  if (source && source !== 'ALL') q.source = source;
  const ref = String(scope.referenceId || scope.reference || '').trim();
  if (ref) {
    const refQ = {
      $or: [
        { referenceId: ref },
        { relatedTransactionId: ref },
        { txnId: ref },
      ],
    };
    q = q.$or || q.$and ? { $and: [q, refQ] } : { ...q, ...refQ };
  }
  const status = String(scope.status || '').trim().toUpperCase();
  if (status && status !== 'ALL') q.status = status;
  const minAmt = String(scope.minAmount || '').trim();
  const maxAmt = String(scope.maxAmount || '').trim();
  if (minAmt || maxAmt) {
    q.amountPaise = {};
    if (minAmt) q.amountPaise.$gte = toPaise(minAmt).ok ? toPaise(minAmt).paise : 0;
    if (maxAmt) q.amountPaise.$lte = toPaise(maxAmt).ok ? toPaise(maxAmt).paise : 0;
  }
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

const CBP_OPENING_PAISE = 2510000;

function legacyAutoCommissionPaise(amountPaise) {
  return Math.round((Number(amountPaise) || 0) / 100);
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

async function rebuildCbpFromOpening(db) {
  const wallet = await ensureWallet(db, 'CBP');
  const meta = { email: 'system', name: 'system', role: 'owner' };
  const credits = Number(wallet.totalCreditsPaise) || 0;
  if (credits < CBP_OPENING_PAISE) {
    const add = await addMoney(db, 'CBP', {
      amount: fromPaise(CBP_OPENING_PAISE - credits),
      remark: 'CBP opening balance ₹25100',
      source: 'opening',
    }, meta);
    if (add.status !== 200) {
      console.warn('CBP opening add failed:', add.json && add.json.error);
    }
  }
  const fresh = await ensureWallet(db, 'CBP');
  let remaining = Number(fresh.totalCreditsPaise) || CBP_OPENING_PAISE;
  const rows = await db.collection('cbc').find(withAlive({})).sort({ dateKey: 1, id: 1 }).toArray();
  const hasZero = rows.some((row) => {
    const status = String(row.transactionStatus || '').toUpperCase();
    if (status === 'REVERSED' || status === 'FAILED' || row.deletedAt) return false;
    const amount = Number(row.amountPaise) > 0 ? Number(row.amountPaise) : toPaise(row.amount ?? row.amountNum).paise;
    const comm = Number(row.commissionPaise) > 0 ? Number(row.commissionPaise) : toPaise(row.commission ?? row.commissionNum).paise;
    return amount > 0 && comm <= 0;
  });
  if (fresh.cbpHistoryRebuilt === 'khatu-10' && !hasZero) return fresh;
  let totalAmt = 0;
  let totalComm = 0;
  let updated = 0;
  for (const row of rows) {
    const status = String(row.transactionStatus || '').toUpperCase();
    if (status === 'REVERSED' || status === 'FAILED' || row.deletedAt) continue;
    const amount = Number(row.amountPaise) > 0 ? Number(row.amountPaise) : toPaise(row.amount ?? row.amountNum).paise;
    if (amount <= 0) continue;
    const previous = remaining;
    const expected = previous - amount;
    let comm = Number(row.commissionPaise) > 0
      ? Number(row.commissionPaise)
      : toPaise(row.commission ?? row.commissionNum).paise;
    if (comm <= 0 || row.commissionBackfilled !== 'khatu-10') {
      if (comm <= 0) comm = legacyAutoCommissionPaise(amount);
    }
    const actual = expected + comm;
    remaining = actual;
    totalAmt += amount;
    totalComm += comm;
    updated += 1;
    await db.collection('cbc').updateOne({ _id: row._id }, {
      $set: {
        previousBalance: fromPaise(previous),
        previousBalancePaise: previous,
        expectedBalance: fromPaise(expected),
        expectedBalancePaise: expected,
        actualBalance: fromPaise(actual),
        actualBalancePaise: actual,
        balance: fromPaise(actual),
        balanceNum: rupeeNum(actual),
        commission: fromPaise(comm),
        commissionNum: rupeeNum(comm),
        commissionPaise: comm,
        amountPaise: amount,
        walletApplied: true,
        transactionStatus: 'SUCCESS',
        commissionBackfilled: 'khatu-10',
        updatedAt: new Date().toISOString(),
      },
    });
  }
  await db.collection('wallets').updateOne({ _id: fresh._id }, {
    $set: {
      currentBalancePaise: remaining,
      totalTransactionAmountPaise: totalAmt,
      totalCommissionPaise: totalComm,
      totalDebitsPaise: totalAmt,
      cbpHistoryRebuilt: 'khatu-10',
      updatedAt: new Date().toISOString(),
    },
  });
  console.log(`CBP history rebuild: ${updated} rows, remaining ${fromPaise(remaining)}, commission ${fromPaise(totalComm)}`);
  return ensureWallet(db, 'CBP');
}

module.exports = {
  ensureWallet,
  getWalletDoc,
  publicWallet,
  publicLedger,
  addMoney,
  withdraw,
  applyUsage,
  previewUsage,
  reverseUsage,
  reverseByRef,
  getService,
  listLedger,
  listCommission,
  listServiceTransactions,
  periodCommission,
  snapshotBoth,
  migrateLegacy,
  rebuildCbpFromOpening,
  CBP_OPENING_PAISE,
  isFailedStatus,
};
