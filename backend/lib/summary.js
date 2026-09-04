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

function amountExpr() {
  return moneyExpr('amount', 'amountNum');
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

  const todayStart = isoDay();
  const [pendingTop, failedTop, todayActs] = await Promise.all([
    db.collection('ctopup').countDocuments(withAlive({ status: 'Pending' })),
    db.collection('ctopup').countDocuments(withAlive({ status: 'Failed' })),
    db.collection('activity').countDocuments({ at: { $gte: `${todayStart}T00:00:00.000Z` } }),
  ]);
  const activeEmployees = employees.filter((e) => e.status !== 'inactive').length;

  return {
    locations: locations.filter((l) => l.status !== 'inactive').length,
    employees: employees.length,
    activeEmployees,
    pending: pendingTop,
    failed: failedTop,
    todayActivity: todayActs,
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

async function ownerDashboard(db) {
  const { khatuLocation, khatuQuery, LOCATION_NAME } = require('./site');
  const loc = await khatuLocation(db);
  const locQ = loc ? khatuQuery(loc) : { locationId: 1 };
  const alive = withAlive(locQ);
  const now = new Date();
  const todayStart = startOfDay(now);
  const weekStart = new Date(todayStart);
  weekStart.setDate(weekStart.getDate() - 6);
  const monthStart = startOfMonth();

  function dayKeys(d) {
    const y = d.getFullYear();
    const m = d.getMonth() + 1;
    const day = d.getDate();
    const yy = String(y).slice(-2);
    const mm = String(m).padStart(2, '0');
    const dd = String(day).padStart(2, '0');
    return [...new Set([
      `${y}-${mm}-${dd}`,
      `${dd}/${mm}/${y}`,
      `${day}/${m}/${y}`,
      `${dd}/${mm}/${yy}`,
      `${day}/${m}/${yy}`,
      `${dd}/${m}/${y}`,
      `${day}/${mm}/${y}`,
    ])];
  }

  function rangeQuery(fromDate) {
    const keys = [];
    const cursor = new Date(fromDate);
    const end = new Date(todayStart);
    end.setDate(end.getDate() + 1);
    while (cursor < end) {
      keys.push(...dayKeys(cursor));
      cursor.setDate(cursor.getDate() + 1);
    }
    return {
      $or: [
        { createdAt: { $gte: fromDate.toISOString() } },
        { date: { $in: keys } },
      ],
    };
  }

  async function moneyGroup(collection, extra) {
    const match = extra ? { $and: [locQ, extra] } : locQ;
    const rows = await db.collection(collection).aggregate([
      { $match: withAlive(match) },
      {
        $group: {
          _id: null,
          n: { $sum: 1 },
          amount: { $sum: amountExpr() },
          commission: { $sum: moneyExpr('commission', 'commissionNum') },
          balance: { $sum: moneyExpr('balance', 'balanceNum') },
        },
      },
    ]).toArray();
    const r = rows[0] || {};
    return {
      n: r.n || 0,
      amount: Math.round((r.amount || 0) * 100) / 100,
      commission: Math.round((r.commission || 0) * 100) / 100,
      balance: Math.round((r.balance || 0) * 100) / 100,
    };
  }

  const todayQ = rangeQuery(todayStart);
  const weekQ = rangeQuery(weekStart);
  const monthQ = rangeQuery(monthStart);

  const [
    sims,
    cbcAll,
    topAll,
    todaySims,
    todayCbc,
    todayTop,
    weekSims,
    weekCbc,
    weekTop,
    monthSims,
    monthCbc,
    monthTop,
    typeRows,
    statusRows,
    activity,
  ] = await Promise.all([
    db.collection('sims').countDocuments(alive),
    moneyGroup('cbc'),
    moneyGroup('ctopup'),
    db.collection('sims').countDocuments(withAlive({ $and: [locQ, todayQ] })),
    moneyGroup('cbc', todayQ),
    moneyGroup('ctopup', todayQ),
    db.collection('sims').countDocuments(withAlive({ $and: [locQ, weekQ] })),
    moneyGroup('cbc', weekQ),
    moneyGroup('ctopup', weekQ),
    db.collection('sims').countDocuments(withAlive({ $and: [locQ, monthQ] })),
    moneyGroup('cbc', monthQ),
    moneyGroup('ctopup', monthQ),
    db.collection('sims').aggregate([
      { $match: alive },
      { $group: { _id: { $ifNull: ['$type', 'CYMN'] }, n: { $sum: 1 } } },
    ]).toArray(),
    db.collection('ctopup').aggregate([
      { $match: alive },
      { $group: { _id: { $ifNull: ['$status', 'Pending'] }, n: { $sum: 1 }, amount: { $sum: amountExpr() } } },
    ]).toArray(),
    db.collection('activity').find({ locationId: Number(loc?.id) || 1 }).sort({ id: -1 }).limit(12).toArray(),
  ]);

  const daily = [];
  for (let i = 6; i >= 0; i -= 1) {
    const d = new Date(todayStart);
    d.setDate(d.getDate() - i);
    const next = new Date(d);
    next.setDate(next.getDate() + 1);
    const q = {
      $or: [
        { createdAt: { $gte: d.toISOString(), $lt: next.toISOString() } },
        { date: { $in: dayKeys(d) } },
      ],
    };
    const [s, c, t] = await Promise.all([
      db.collection('sims').countDocuments(withAlive({ $and: [locQ, q] })),
      moneyGroup('cbc', q),
      moneyGroup('ctopup', q),
    ]);
    daily.push({
      date: isoDay(d),
      label: `${d.getDate()}/${d.getMonth() + 1}`,
      sims: s,
      cbc: c.n,
      ctopup: t.n,
      cbcAmount: c.amount,
      ctopupAmount: t.amount,
      commission: Math.round((c.commission + t.commission) * 100) / 100,
      walletChange: Math.round(((-c.amount - t.amount) + (c.commission + t.commission)) * 100) / 100,
      balance: Math.round((c.balance + t.balance) * 100) / 100,
      amount: Math.round((c.amount + t.amount) * 100) / 100,
    });
  }

  const portalTypes = { CYMN: 0, MNP: 0, Swap: 0, Postpaid: 0 };
  for (const r of typeRows) {
    const key = String(r._id || 'CYMN');
    portalTypes[key] = r.n;
  }
  const ctopupStatus = {};
  for (const r of statusRows) {
    ctopupStatus[String(r._id || 'Pending')] = {
      n: r.n || 0,
      amount: Math.round((r.amount || 0) * 100) / 100,
    };
  }

  const paid = ctopupStatus.Paid || ctopupStatus.paid || { n: 0, amount: 0 };
  const pending = ctopupStatus.Pending || ctopupStatus.pending || { n: 0, amount: 0 };
  const failed = ctopupStatus.Failed || ctopupStatus.failed || { n: 0, amount: 0 };

  const { snapshot, remainingOf } = require('./wallet');
  const snap = await snapshot(db);

  return {
    locationName: loc?.name || LOCATION_NAME,
    generatedAt: now.toISOString(),
    sims,
    cbc: cbcAll.n,
    ctopup: topAll.n,
    totals: {
      records: sims + cbcAll.n + topAll.n,
      walletAmount: snap.walletAmount,
      cbcAmount: cbcAll.amount,
      ctopupAmount: topAll.amount,
      combinedAmount: Math.round((cbcAll.amount + topAll.amount) * 100) / 100,
      cbcCommission: cbcAll.commission,
      ctopupCommission: topAll.commission,
      combinedCommission: Math.round((cbcAll.commission + topAll.commission) * 100) / 100,
      cbcBalance: remainingOf(snap.walletAmount, cbcAll.amount, cbcAll.commission),
      ctopupBalance: remainingOf(snap.walletAmount, topAll.amount, topAll.commission),
      combinedBalance: snap.remainingBalance,
      cbcNet: snap.cbcNet,
      ctopupNet: snap.ctopupNet,
      avgCbc: cbcAll.n ? Math.round((cbcAll.amount / cbcAll.n) * 100) / 100 : 0,
      avgCtopup: topAll.n ? Math.round((topAll.amount / topAll.n) * 100) / 100 : 0,
    },
    today: {
      sims: todaySims,
      cbc: todayCbc.n,
      ctopup: todayTop.n,
      cbcAmount: todayCbc.amount,
      ctopupAmount: todayTop.amount,
      combinedAmount: Math.round((todayCbc.amount + todayTop.amount) * 100) / 100,
      combinedCommission: Math.round((todayCbc.commission + todayTop.commission) * 100) / 100,
      walletChange: remainingOf(0, todayCbc.amount + todayTop.amount, todayCbc.commission + todayTop.commission),
      combinedBalance: remainingOf(0, todayCbc.amount + todayTop.amount, todayCbc.commission + todayTop.commission),
    },
    week: {
      sims: weekSims,
      cbc: weekCbc.n,
      ctopup: weekTop.n,
      cbcAmount: weekCbc.amount,
      ctopupAmount: weekTop.amount,
      combinedAmount: Math.round((weekCbc.amount + weekTop.amount) * 100) / 100,
      combinedCommission: Math.round((weekCbc.commission + weekTop.commission) * 100) / 100,
      walletChange: remainingOf(0, weekCbc.amount + weekTop.amount, weekCbc.commission + weekTop.commission),
      combinedBalance: remainingOf(0, weekCbc.amount + weekTop.amount, weekCbc.commission + weekTop.commission),
    },
    month: {
      sims: monthSims,
      cbc: monthCbc.n,
      ctopup: monthTop.n,
      cbcAmount: monthCbc.amount,
      ctopupAmount: monthTop.amount,
      combinedAmount: Math.round((monthCbc.amount + monthTop.amount) * 100) / 100,
      combinedCommission: Math.round((monthCbc.commission + monthTop.commission) * 100) / 100,
      walletChange: remainingOf(0, monthCbc.amount + monthTop.amount, monthCbc.commission + monthTop.commission),
      combinedBalance: remainingOf(0, monthCbc.amount + monthTop.amount, monthCbc.commission + monthTop.commission),
    },
    portalTypes,
    ctopupStatus: {
      Paid: paid,
      Pending: pending,
      Failed: failed,
    },
    daily,
    activity: activity.map((a) => ({
      at: a.at || '',
      name: a.name || a.email || '',
      action: a.action || '',
      section: a.section || '',
      detail: a.detail || '',
    })),
  };
}

module.exports = { adminSummary, locationSummary, ownerDashboard, money: moneyNumber };
