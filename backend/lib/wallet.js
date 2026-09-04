'use strict';

const { moneyNumber } = require('./password');
const { withAlive } = require('./alive');
const { dateKeyOf } = require('./dates');
const { khatuLocation, khatuQuery } = require('./site');
const { logActivity } = require('./activity');

function roundMoney(n) {
  return Math.round((Number(n) || 0) * 100) / 100;
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

function remainingOf(wallet, amount, commission) {
  return roundMoney(wallet - amount + commission);
}

async function snapshot(db) {
  const loc = await khatuLocation(db);
  const locQ = loc ? khatuQuery(loc) : { locationId: 1 };
  const wallet = roundMoney(moneyNumber(loc?.walletAmountNum ?? loc?.walletAmount));
  const [cbc, ctopup] = await Promise.all([
    moneySum(db, 'cbc', locQ),
    moneySum(db, 'ctopup', locQ),
  ]);
  const combinedAmount = roundMoney(cbc.amount + ctopup.amount);
  const combinedCommission = roundMoney(cbc.commission + ctopup.commission);
  return {
    walletAmount: wallet,
    remainingBalance: remainingOf(wallet, combinedAmount, combinedCommission),
    cbcAmount: cbc.amount,
    cbcCommission: cbc.commission,
    cbcNet: remainingOf(0, cbc.amount, cbc.commission),
    ctopupAmount: ctopup.amount,
    ctopupCommission: ctopup.commission,
    ctopupNet: remainingOf(0, ctopup.amount, ctopup.commission),
    combinedAmount,
    combinedCommission,
  };
}

async function recomputeBalances(db) {
  const loc = await khatuLocation(db);
  const locQ = loc ? khatuQuery(loc) : { locationId: 1 };
  const wallet = roundMoney(moneyNumber(loc?.walletAmountNum ?? loc?.walletAmount));
  const project = {
    _id: 1,
    dateKey: 1,
    date: 1,
    id: 1,
    amountNum: 1,
    amount: 1,
    commissionNum: 1,
    commission: 1,
  };
  const [cbcRows, topRows] = await Promise.all([
    db.collection('cbc').find(withAlive(locQ)).project(project).toArray(),
    db.collection('ctopup').find(withAlive(locQ)).project(project).toArray(),
  ]);
  const all = [
    ...cbcRows.map((r) => ({ ...r, col: 'cbc' })),
    ...topRows.map((r) => ({ ...r, col: 'ctopup' })),
  ].sort((a, b) => {
    const ka = a.dateKey || dateKeyOf(a.date) || '';
    const kb = b.dateKey || dateKeyOf(b.date) || '';
    if (ka !== kb) return ka < kb ? -1 : 1;
    const ida = Number(a.id) || 0;
    const idb = Number(b.id) || 0;
    if (ida !== idb) return ida - idb;
    return String(a.col).localeCompare(String(b.col));
  });
  let remaining = wallet;
  const bulk = { cbc: [], ctopup: [] };
  for (const r of all) {
    remaining = remainingOf(remaining, moneyNumber(r.amountNum ?? r.amount), moneyNumber(r.commissionNum ?? r.commission));
    bulk[r.col].push({
      updateOne: {
        filter: { _id: r._id },
        update: { $set: { balance: String(remaining), balanceNum: remaining } },
      },
    });
  }
  if (bulk.cbc.length) await db.collection('cbc').bulkWrite(bulk.cbc, { ordered: true });
  if (bulk.ctopup.length) await db.collection('ctopup').bulkWrite(bulk.ctopup, { ordered: true });
  return remaining;
}

async function setWallet(db, body, meta) {
  const amount = String(body?.amount ?? body?.walletAmount ?? body?.balance ?? '').trim();
  const loc = await khatuLocation(db);
  if (!loc) return { status: 404, json: { ok: false, error: 'Location nahi mili' } };
  const num = moneyNumber(amount);
  await db.collection('locations').updateOne(
    { _id: loc._id },
    {
      $set: {
        walletAmount: amount || String(num),
        walletAmountNum: num,
        updatedAt: new Date().toISOString(),
      },
    },
  );
  await recomputeBalances(db);
  await logActivity(db, {
    email: meta?.email || '',
    role: meta?.role || 'owner',
    name: meta?.name || '',
    action: 'update',
    section: 'wallet',
    locationId: loc.id,
    locationName: loc.name || 'Khatushyamji',
    detail: `${meta?.name || meta?.email || 'Owner'} set wallet/total amount to ₹${num}`,
  });
  const snap = await snapshot(db);
  return { status: 200, json: { ok: true, ...snap } };
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
};
