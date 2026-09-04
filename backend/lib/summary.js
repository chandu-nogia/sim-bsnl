'use strict';

const { withAlive } = require('./alive');
const { moneyNumber } = require('./password');

function startOfDay(d = new Date()) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function isoDay(d = new Date()) {
  return startOfDay(d).toISOString().slice(0, 10);
}

function startOfMonth() {
  const d = startOfDay();
  d.setDate(1);
  return d;
}

function startOfWeek() {
  const d = startOfDay();
  d.setDate(d.getDate() - d.getDay());
  return d;
}

function emptyBucket(loc) {
  return {
    id: Number(loc.id) || 0,
    name: loc.name || 'Unknown',
    code: loc.code || '',
    address: loc.address || '',
    status: loc.status || 'active',
    email: loc.email || '',
    employees: 0,
    sims: 0,
    newUsers: 0,
    newUsersToday: 0,
    newUsersWeek: 0,
    newUsersMonth: 0,
    cbcCount: 0,
    cbcAmount: 0,
    cbcAmountToday: 0,
    cbcAmountMonth: 0,
    ctopupCount: 0,
    ctopupAmount: 0,
    ctopupAmountToday: 0,
    ctopupAmountMonth: 0,
    transactions: 0,
  };
}

function amountExpr() {
  return {
    $convert: {
      input: { $ifNull: ['$amountNum', '$amount'] },
      to: 'double',
      onError: 0,
      onNull: 0,
    },
  };
}

async function simStats(db) {
  const today = isoDay();
  const week = isoDay(startOfWeek());
  const month = isoDay(startOfMonth());
  return db.collection('sims').aggregate([
    { $match: withAlive({}) },
    {
      $group: {
        _id: '$locationId',
        n: { $sum: 1 },
        today: { $sum: { $cond: [{ $eq: [{ $substrBytes: [{ $ifNull: ['$date', ''] }, 0, 10] }, today] }, 1, 0] } },
        week: { $sum: { $cond: [{ $gte: [{ $substrBytes: [{ $ifNull: ['$date', ''] }, 0, 10] }, week] }, 1, 0] } },
        month: { $sum: { $cond: [{ $gte: [{ $substrBytes: [{ $ifNull: ['$date', ''] }, 0, 10] }, month] }, 1, 0] } },
      },
    },
  ]).toArray();
}

async function moneyStats(db, collection) {
  const today = isoDay();
  const month = isoDay(startOfMonth());
  return db.collection(collection).aggregate([
    { $match: withAlive({}) },
    {
      $group: {
        _id: '$locationId',
        n: { $sum: 1 },
        amount: { $sum: amountExpr() },
        todayAmt: {
          $sum: {
            $cond: [{ $eq: [{ $substrBytes: [{ $ifNull: ['$date', ''] }, 0, 10] }, today] }, amountExpr(), 0],
          },
        },
        monthAmt: {
          $sum: {
            $cond: [{ $gte: [{ $substrBytes: [{ $ifNull: ['$date', ''] }, 0, 10] }, month] }, amountExpr(), 0],
          },
        },
      },
    },
  ]).toArray();
}

async function dailyTxns(db) {
  const from = isoDay(new Date(Date.now() - 13 * 86400000));
  const rows = await db.collection('cbc').aggregate([
    { $match: withAlive({ date: { $gte: from } }) },
    { $group: { _id: { $substrBytes: ['$date', 0, 10] }, count: { $sum: 1 }, amount: { $sum: amountExpr() } } },
  ]).toArray();
  const top = await db.collection('ctopup').aggregate([
    { $match: withAlive({ date: { $gte: from } }) },
    { $group: { _id: { $substrBytes: ['$date', 0, 10] }, count: { $sum: 1 }, amount: { $sum: amountExpr() } } },
  ]).toArray();
  const daily = {};
  for (let i = 13; i >= 0; i -= 1) {
    const d = isoDay(new Date(Date.now() - i * 86400000));
    daily[d] = { date: d, count: 0, amount: 0 };
  }
  for (const r of [...rows, ...top]) {
    if (!daily[r._id]) continue;
    daily[r._id].count += r.count;
    daily[r._id].amount += r.amount;
  }
  return Object.values(daily);
}

async function monthlyAmounts(db) {
  const start = new Date();
  start.setMonth(start.getMonth() - 5, 1);
  const from = start.toISOString().slice(0, 7);
  const cbc = await db.collection('cbc').aggregate([
    { $match: withAlive({}) },
    { $group: { _id: { $substrBytes: ['$date', 0, 7] }, amount: { $sum: amountExpr() } } },
  ]).toArray();
  const top = await db.collection('ctopup').aggregate([
    { $match: withAlive({}) },
    { $group: { _id: { $substrBytes: ['$date', 0, 7] }, amount: { $sum: amountExpr() } } },
  ]).toArray();
  const monthly = {};
  for (let i = 5; i >= 0; i -= 1) {
    const d = new Date();
    d.setMonth(d.getMonth() - i, 1);
    const k = d.toISOString().slice(0, 7);
    monthly[k] = { month: k, cbc: 0, ctopup: 0 };
  }
  for (const r of cbc) if (monthly[r._id] && r._id >= from) monthly[r._id].cbc = r.amount;
  for (const r of top) if (monthly[r._id] && r._id >= from) monthly[r._id].ctopup = r.amount;
  return Object.values(monthly);
}

async function adminSummary(db) {
  const [locations, employees, simsG, cbcG, topG, activity, byEmp, daily, monthly] = await Promise.all([
    db.collection('locations').find().sort({ id: 1 }).toArray(),
    db.collection('users').find({ role: 'employee' }).toArray(),
    simStats(db),
    moneyStats(db, 'cbc'),
    moneyStats(db, 'ctopup'),
    db.collection('activity').find().sort({ id: -1 }).limit(200).project({ email: 1 }).toArray(),
    db.collection('sims').aggregate([
      { $match: withAlive({}) },
      { $group: { _id: { $toLower: { $ifNull: ['$createdBy', ''] } }, count: { $sum: 1 } } },
    ]).toArray(),
    dailyTxns(db),
    monthlyAmounts(db),
  ]);

  const byId = {};
  for (const loc of locations) {
    if (loc.status === 'inactive') continue;
    byId[loc.id] = emptyBucket(loc);
  }

  function bucket(locationId) {
    const id = Number(locationId) || 0;
    if (!byId[id]) {
      const loc = locations.find((l) => Number(l.id) === id);
      if (loc && loc.status === 'inactive') return null;
      byId[id] = emptyBucket(loc || { id, name: 'Unknown' });
    }
    return byId[id];
  }

  for (const e of employees) {
    const ids = Array.isArray(e.assignedLocations) && e.assignedLocations.length
      ? e.assignedLocations.map(Number)
      : (e.locationId ? [Number(e.locationId)] : []);
    for (const id of ids) {
      if (byId[id]) byId[id].employees += 1;
    }
  }
  for (const r of simsG) {
    const b = bucket(r._id);
    if (!b) continue;
    b.sims = r.n;
    b.newUsers = r.n;
    b.newUsersToday = r.today;
    b.newUsersWeek = r.week;
    b.newUsersMonth = r.month;
  }
  for (const r of cbcG) {
    const b = bucket(r._id);
    if (!b) continue;
    b.cbcCount = r.n;
    b.cbcAmount = r.amount;
    b.cbcAmountToday = r.todayAmt;
    b.cbcAmountMonth = r.monthAmt;
    b.transactions += r.n;
  }
  for (const r of topG) {
    const b = bucket(r._id);
    if (!b) continue;
    b.ctopupCount = r.n;
    b.ctopupAmount = r.amount;
    b.ctopupAmountToday = r.todayAmt;
    b.ctopupAmountMonth = r.monthAmt;
    b.transactions += r.n;
  }

  const list = Object.values(byId).sort((a, b) => a.id - b.id);
  const totals = list.reduce(
    (a, b) => ({
      sims: a.sims + b.sims,
      newUsers: a.newUsers + b.newUsers,
      newUsersToday: a.newUsersToday + b.newUsersToday,
      newUsersWeek: a.newUsersWeek + b.newUsersWeek,
      newUsersMonth: a.newUsersMonth + b.newUsersMonth,
      cbcCount: a.cbcCount + b.cbcCount,
      cbcAmount: a.cbcAmount + b.cbcAmount,
      cbcAmountToday: a.cbcAmountToday + b.cbcAmountToday,
      cbcAmountMonth: a.cbcAmountMonth + b.cbcAmountMonth,
      ctopupCount: a.ctopupCount + b.ctopupCount,
      ctopupAmount: a.ctopupAmount + b.ctopupAmount,
      ctopupAmountToday: a.ctopupAmountToday + b.ctopupAmountToday,
      ctopupAmountMonth: a.ctopupAmountMonth + b.ctopupAmountMonth,
      transactions: a.transactions + b.transactions,
    }),
    {
      sims: 0,
      newUsers: 0,
      newUsersToday: 0,
      newUsersWeek: 0,
      newUsersMonth: 0,
      cbcCount: 0,
      cbcAmount: 0,
      cbcAmountToday: 0,
      cbcAmountMonth: 0,
      ctopupCount: 0,
      ctopupAmount: 0,
      ctopupAmountToday: 0,
      ctopupAmountMonth: 0,
      transactions: 0,
    },
  );

  const empCount = Object.fromEntries(byEmp.map((r) => [r._id, r.count]));
  const empActivity = {};
  for (const a of activity) {
    const k = a.email || 'unknown';
    empActivity[k] = (empActivity[k] || 0) + 1;
  }

  return {
    locations: locations.filter((l) => l.status !== 'inactive').length,
    employees: employees.length,
    totals,
    byLocation: list,
    newUsersByEmployee: employees.map((e) => ({
      email: e.email,
      name: e.name || e.email,
      count: empCount[String(e.email || '').toLowerCase()] || 0,
    })),
    charts: {
      usersByLocation: list.map((l) => ({ name: l.name, value: l.newUsers })),
      cbcByLocation: list.map((l) => ({ name: l.name, value: Math.round(l.cbcAmount) })),
      ctopupByLocation: list.map((l) => ({ name: l.name, value: Math.round(l.ctopupAmount) })),
      dailyTxns: daily,
      monthlyAmounts: monthly,
      employeeActivity: Object.entries(empActivity)
        .map(([email, count]) => ({ email, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 12),
    },
  };
}

async function locationSummary(db, user, locationId) {
  const id = Number(locationId);
  if (!id) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
  if (user.role !== 'admin') {
    const ids = Array.isArray(user.assignedLocations) ? user.assignedLocations.map(Number) : [];
    if (!ids.includes(id) && Number(user.locationId) !== id) {
      return { status: 403, json: { ok: false, error: 'Is jagah ki permission nahi' } };
    }
  }
  const loc = await db.collection('locations').findOne({ id });
  if (!loc) return { status: 404, json: { ok: false, error: 'Jagah nahi mili' } };
  const full = await adminSummary(db);
  const row = full.byLocation.find((l) => Number(l.id) === id) || emptyBucket(loc);
  return { status: 200, json: { ok: true, location: row } };
}

module.exports = { adminSummary, locationSummary, money: moneyNumber };
