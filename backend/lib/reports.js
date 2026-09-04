'use strict';

const { money } = require('./summary');
const { assignedIds, mongoListQuery } = require('./rbac');
const { publicActivity } = require('./activity');
const { withAlive } = require('./alive');

function inRange(iso, from, to) {
  const d = String(iso || '').slice(0, 10);
  if (from && d < from) return false;
  if (to && d > to) return false;
  return true;
}

function rowDay(r) {
  return String(r.date || r.createdAt || '').slice(0, 10);
}

async function buildReport(db, user, query) {
  const type = String(query?.type || 'location').trim();
  const from = String(query?.from || '').slice(0, 10);
  const to = String(query?.to || '').slice(0, 10);
  const employee = String(query?.employee || '').trim().toLowerCase();
  const scope = {};
  const ids = assignedIds(user);
  const locFilter = Number.parseInt(String(query?.locationId || ''), 10) || 0;
  if (ids === null) {
    if (locFilter) scope.locationId = locFilter;
    else scope.all = true;
  } else {
    if (locFilter && !ids.includes(locFilter)) {
      return { status: 403, json: { ok: false, error: 'Is jagah ki permission nahi' } };
    }
    if (locFilter) scope.locationId = locFilter;
    else scope.locationIds = ids;
  }
  const q = withAlive(mongoListQuery(scope));
  const [locations, employees, sims, cbc, ctopup, activity] = await Promise.all([
    db.collection('locations').find(ids === null ? {} : { id: { $in: ids } }).toArray(),
    db.collection('users').find({ role: 'employee' }).toArray(),
    db.collection('sims').find(q).toArray(),
    db.collection('cbc').find(q).toArray(),
    db.collection('ctopup').find(q).toArray(),
    db.collection('activity').find(ids === null ? {} : mongoListQuery(scope)).sort({ id: -1 }).limit(2000).toArray(),
  ]);

  const locName = {};
  for (const l of locations) locName[Number(l.id)] = l.name || '';

  const simsF = sims.filter((r) => inRange(rowDay(r), from, to));
  const cbcF = cbc.filter((r) => inRange(rowDay(r), from, to));
  const ctopF = ctopup.filter((r) => inRange(rowDay(r), from, to));
  const actF = activity.filter((r) => inRange(String(r.at || '').slice(0, 10), from, to));

  const byEmp = (rows) => {
    const list = employee ? rows.filter((r) => String(r.createdBy || r.employeeEmail || '').toLowerCase() === employee) : rows;
    return list;
  };

  if (type === 'employee') {
    const rows = employees.map((e) => {
      const mail = String(e.email || '').toLowerCase();
      const s = byEmp(simsF).filter((r) => String(r.createdBy || '').toLowerCase() === mail);
      const c = byEmp(cbcF).filter((r) => String(r.createdBy || '').toLowerCase() === mail);
      const t = byEmp(ctopF).filter((r) => String(r.createdBy || '').toLowerCase() === mail);
      return {
        employee: e.name || e.email,
        email: e.email,
        locations: (e.assignedLocations || []).map((id) => locName[Number(id)] || id).join(', '),
        newUsers: s.length,
        cbcCount: c.length,
        cbcAmount: c.reduce((a, r) => a + money(r.amount), 0),
        ctopupCount: t.length,
        ctopupAmount: t.reduce((a, r) => a + money(r.amount), 0),
      };
    });
    return { status: 200, json: { ok: true, title: 'Employee-wise report', rows } };
  }

  if (type === 'cbc') {
    const rows = byEmp(cbcF).map((r) => ({
      date: r.date || '',
      name: r.name || '',
      amount: money(r.amount),
      transactionId: r.transactionId || '',
      location: r.locationName || locName[Number(r.locationId)] || '',
      createdBy: r.createdBy || '',
    }));
    return { status: 200, json: { ok: true, title: 'CBC amount report', rows } };
  }

  if (type === 'ctopup') {
    const rows = byEmp(ctopF).map((r) => ({
      date: r.date || '',
      name: r.name || '',
      amount: money(r.amount),
      transactionId: r.transactionId || '',
      status: r.status || '',
      location: r.locationName || locName[Number(r.locationId)] || '',
      createdBy: r.createdBy || '',
    }));
    return { status: 200, json: { ok: true, title: 'C-TopUp amount report', rows } };
  }

  if (type === 'users' || type === 'newusers') {
    const rows = byEmp(simsF).map((r) => ({
      date: r.date || String(r.createdAt || '').slice(0, 10),
      name: r.name || '',
      mobile: r.mobile || '',
      type: r.type || '',
      location: r.locationName || locName[Number(r.locationId)] || '',
      createdBy: r.createdBy || '',
    }));
    return { status: 200, json: { ok: true, title: 'New user report', rows } };
  }

  if (type === 'activity') {
    const rows = actF
      .filter((r) => !employee || String(r.email || '').toLowerCase() === employee)
      .map(publicActivity);
    return { status: 200, json: { ok: true, title: 'Activity report', rows } };
  }

  if (type === 'daily' || type === 'weekly' || type === 'monthly') {
    const bucket = {};
    const keyOf = (d) => {
      if (!d) return '';
      if (type === 'monthly') return d.slice(0, 7);
      if (type === 'weekly') {
        const dt = new Date(`${d}T00:00:00`);
        const start = new Date(dt);
        start.setDate(dt.getDate() - dt.getDay());
        return start.toISOString().slice(0, 10);
      }
      return d;
    };
    const add = (r, kind) => {
      const k = keyOf(rowDay(r));
      if (!k) return;
      if (!bucket[k]) bucket[k] = { period: k, newUsers: 0, cbcAmount: 0, ctopupAmount: 0, transactions: 0 };
      if (kind === 'sim') bucket[k].newUsers += 1;
      if (kind === 'cbc') {
        bucket[k].cbcAmount += money(r.amount);
        bucket[k].transactions += 1;
      }
      if (kind === 'ctopup') {
        bucket[k].ctopupAmount += money(r.amount);
        bucket[k].transactions += 1;
      }
    };
    for (const r of byEmp(simsF)) add(r, 'sim');
    for (const r of byEmp(cbcF)) add(r, 'cbc');
    for (const r of byEmp(ctopF)) add(r, 'ctopup');
    const rows = Object.values(bucket).sort((a, b) => String(a.period).localeCompare(String(b.period)));
    return { status: 200, json: { ok: true, title: `${type} report`, rows } };
  }

  const rows = locations.map((loc) => {
    const id = Number(loc.id);
    const s = simsF.filter((r) => Number(r.locationId) === id);
    const c = cbcF.filter((r) => Number(r.locationId) === id);
    const t = ctopF.filter((r) => Number(r.locationId) === id);
    const staff = employees.filter((e) => asIncludes(e.assignedLocations, id) || Number(e.locationId) === id);
    return {
      location: loc.name || '',
      code: loc.code || '',
      employees: staff.length,
      newUsers: s.length,
      cbcAmount: c.reduce((a, r) => a + money(r.amount), 0),
      ctopupAmount: t.reduce((a, r) => a + money(r.amount), 0),
      transactions: c.length + t.length,
    };
  });
  return { status: 200, json: { ok: true, title: 'Location-wise report', rows } };
}

function asIncludes(arr, id) {
  return Array.isArray(arr) && arr.map(Number).includes(Number(id));
}

module.exports = { buildReport };
