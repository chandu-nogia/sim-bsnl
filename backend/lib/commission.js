'use strict';

const {
  computeUsage,
  calculateUsageCommission,
  validateUsage,
  resolveUsageCommission,
  commissionFromRateBps,
  configuredCommissionPaise,
  fromPaise,
  toPaise,
} = require('./money');

const DEFAULT_RATE_BPS = 100;

function percentFromBps(bps) {
  return (Number(bps) || DEFAULT_RATE_BPS) / 100;
}

function bpsFromPercent(raw) {
  const n = Number(String(raw ?? '').trim());
  if (!Number.isFinite(n) || n < 0 || n > 100) return null;
  return Math.round(n * 100);
}

async function ensureRates(db) {
  const col = db.collection('settings');
  let row = await col.findOne({ key: 'commission' });
  if (row) return row;
  const now = new Date().toISOString();
  row = {
    key: 'commission',
    cbpRateBps: DEFAULT_RATE_BPS,
    ctopupRateBps: DEFAULT_RATE_BPS,
    createdAt: now,
    updatedAt: now,
  };
  await col.insertOne(row);
  return row;
}

async function getRates(db) {
  const row = await ensureRates(db);
  const cbp = Number(row.cbpRateBps) > 0 ? Number(row.cbpRateBps) : DEFAULT_RATE_BPS;
  const top = Number(row.ctopupRateBps) > 0 ? Number(row.ctopupRateBps) : DEFAULT_RATE_BPS;
  return {
    cbpRateBps: cbp,
    ctopupRateBps: top,
    cbpCommissionPercent: percentFromBps(cbp),
    ctopupCommissionPercent: percentFromBps(top),
  };
}

function rateBpsFor(service, rates) {
  const svc = String(service || '').toUpperCase();
  if (svc === 'CTOPUP') return rates.ctopupRateBps;
  return rates.cbpRateBps;
}

async function publicConfig(db) {
  const rates = db ? await getRates(db) : {
    cbpRateBps: DEFAULT_RATE_BPS,
    ctopupRateBps: DEFAULT_RATE_BPS,
    cbpCommissionPercent: 1,
    ctopupCommissionPercent: 1,
  };
  return {
    commissionMode: 'rate',
    formula: 'newBalance = oldBalance - amount + commission',
    commissionPercent: rates.cbpCommissionPercent,
    cbpCommissionPercent: rates.cbpCommissionPercent,
    ctopupCommissionPercent: rates.ctopupCommissionPercent,
    cbpRateBps: rates.cbpRateBps,
    ctopupRateBps: rates.ctopupRateBps,
    commissionNote: 'Commission rate Settings se aati hai. Frontend commission ignore hoti hai.',
    ctopupTypes: ['Recharge', 'Activation', 'Replacement', 'Port', 'Other'],
  };
}

async function setRates(db, body, meta = {}) {
  await ensureRates(db);
  const patch = {};
  if (body?.cbpCommissionPercent != null || body?.cbpRate != null) {
    const bps = bpsFromPercent(body.cbpCommissionPercent ?? body.cbpRate);
    if (bps == null) return { status: 400, json: { ok: false, error: 'CBP commission rate 0 se 100 ke beech honi chahiye' } };
    patch.cbpRateBps = bps;
  }
  if (body?.ctopupCommissionPercent != null || body?.ctopupRate != null) {
    const bps = bpsFromPercent(body.ctopupCommissionPercent ?? body.ctopupRate);
    if (bps == null) return { status: 400, json: { ok: false, error: 'CTOPUP commission rate 0 se 100 ke beech honi chahiye' } };
    patch.ctopupRateBps = bps;
  }
  if (!Object.keys(patch).length) {
    return { status: 400, json: { ok: false, error: 'CBP ya CTOPUP rate likho' } };
  }
  patch.updatedAt = new Date().toISOString();
  patch.updatedBy = meta.email || '';
  await db.collection('settings').updateOne({ key: 'commission' }, { $set: patch });
  return { status: 200, json: { ok: true, ...(await publicConfig(db)) } };
}

function applyCommissionFromBalances(row, previousPaise, rateBps = DEFAULT_RATE_BPS) {
  const amount = toPaise(row.amount);
  if (!amount.ok || amount.paise <= 0) {
    row.commission = '0.00';
    row.commissionNum = 0;
    row.commissionPaise = 0;
    row.previousBalancePaise = previousPaise || 0;
    row.expectedBalancePaise = (previousPaise || 0) - (amount.ok ? amount.paise : 0);
    return row;
  }
  const resolved = resolveUsageCommission({
    amountPaise: amount.paise,
    rateBps,
  });
  const calc = computeUsage({
    previousPaise: previousPaise || 0,
    amountPaise: amount.paise,
    commissionPaise: resolved.ok ? resolved.commissionPaise : 0,
  });
  row.amountPaise = calc.amountPaise;
  row.commission = calc.commission;
  row.commissionNum = calc.commissionPaise / 100;
  row.commissionPaise = calc.commissionPaise;
  row.previousBalance = calc.previous;
  row.previousBalancePaise = calc.previousPaise;
  row.expectedBalance = calc.expected;
  row.expectedBalancePaise = calc.expectedPaise;
  row.actualBalance = calc.newBalance;
  row.actualBalancePaise = calc.newBalancePaise;
  row.balance = calc.newBalance;
  row.balanceNum = calc.newBalancePaise / 100;
  row.balancePaise = calc.newBalancePaise;
  return row;
}

module.exports = {
  publicConfig,
  getRates,
  setRates,
  ensureRates,
  rateBpsFor,
  calculateUsageCommission,
  validateUsage,
  applyCommissionFromBalances,
  configuredCommissionPaise,
  commissionFromRateBps,
  fromPaise,
  DEFAULT_RATE_BPS,
};
