'use strict';

function money(v) {
  const n = Number(String(v ?? '').replace(/[^0-9.]/g, ''));
  return Number.isFinite(n) ? n : 0;
}

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

function rowDay(r) {
  return String(r.date || r.createdAt || '').slice(0, 10);
}

function assignedHas(user, locId) {
  const ids = Array.isArray(user.assignedLocations) ? user.assignedLocations.map(Number) : [];
  return ids.includes(Number(locId)) || Number(user.locationId) === Number(locId);
}

async function adminSummary(db) {
  const [locations, employees, sims, cbc, ctopup, activity] = await Promise.all([
    db.collection('locations').find().sort({ id: 1 }).toArray(),
    db.collection('users').find({ role: 'employee' }).toArray(),
    db.collection('sims').find().toArray(),
    db.collection('cbc').find().toArray(),
    db.collection('ctopup').find().toArray(),
    db.collection('activity').find().sort({ id: -1 }).limit(800).toArray(),
  ]);

  const today = isoDay();
  const week = isoDay(startOfWeek());
  const month = isoDay(startOfMonth());

  const byId = {};
  for (const loc of locations) {
    byId[loc.id] = {
      id: Number(loc.id),
      name: loc.name || '',
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

  function bucket(locationId) {
    const id = Number(locationId) || 0;
    if (!byId[id]) {
      byId[id] = {
        id,
        name: 'Unknown',
        code: '',
        address: '',
        status: 'active',
        email: '',
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

  for (const r of sims) {
    const b = bucket(r.locationId);
    b.sims += 1;
    b.newUsers += 1;
    const d = rowDay(r);
    if (d === today) b.newUsersToday += 1;
    if (d >= week) b.newUsersWeek += 1;
    if (d >= month) b.newUsersMonth += 1;
  }
  for (const r of cbc) {
    const b = bucket(r.locationId);
    const amt = money(r.amount);
    const d = rowDay(r);
    b.cbcCount += 1;
    b.cbcAmount += amt;
    b.transactions += 1;
    if (d === today) b.cbcAmountToday += amt;
    if (d >= month) b.cbcAmountMonth += amt;
  }
  for (const r of ctopup) {
    const b = bucket(r.locationId);
    const amt = money(r.amount);
    const d = rowDay(r);
    b.ctopupCount += 1;
    b.ctopupAmount += amt;
    b.transactions += 1;
    if (d === today) b.ctopupAmountToday += amt;
    if (d >= month) b.ctopupAmountMonth += amt;
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

  const empActivity = {};
  for (const a of activity) {
    const k = a.email || 'unknown';
    empActivity[k] = (empActivity[k] || 0) + 1;
  }

  const daily = {};
  for (let i = 13; i >= 0; i -= 1) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    daily[isoDay(d)] = { date: isoDay(d), count: 0, amount: 0 };
  }
  for (const r of [...cbc, ...ctopup]) {
    const d = rowDay(r);
    if (!daily[d]) continue;
    daily[d].count += 1;
    daily[d].amount += money(r.amount);
  }

  const monthly = {};
  for (let i = 5; i >= 0; i -= 1) {
    const d = new Date();
    d.setMonth(d.getMonth() - i, 1);
    const k = d.toISOString().slice(0, 7);
    monthly[k] = { month: k, cbc: 0, ctopup: 0 };
  }
  for (const r of cbc) {
    const k = rowDay(r).slice(0, 7);
    if (monthly[k]) monthly[k].cbc += money(r.amount);
  }
  for (const r of ctopup) {
    const k = rowDay(r).slice(0, 7);
    if (monthly[k]) monthly[k].ctopup += money(r.amount);
  }

  return {
    locations: locations.length,
    employees: employees.length,
    totals,
    byLocation: list,
    newUsersByEmployee: employees.map((e) => ({
      email: e.email,
      name: e.name || e.email,
      count: sims.filter((r) => String(r.createdBy || '').toLowerCase() === String(e.email || '').toLowerCase()).length,
    })),
    charts: {
      usersByLocation: list.map((l) => ({ name: l.name, value: l.newUsers })),
      cbcByLocation: list.map((l) => ({ name: l.name, value: Math.round(l.cbcAmount) })),
      ctopupByLocation: list.map((l) => ({ name: l.name, value: Math.round(l.ctopupAmount) })),
      dailyTxns: Object.values(daily),
      monthlyAmounts: Object.values(monthly),
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
  const full = await adminSummary(db);
  const loc = full.byLocation.find((l) => Number(l.id) === id);
  if (!loc) return { status: 404, json: { ok: false, error: 'Jagah nahi mili' } };
  return { status: 200, json: { ok: true, location: loc } };
}

module.exports = { adminSummary, locationSummary, money, assignedHas };
