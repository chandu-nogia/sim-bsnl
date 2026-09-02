'use strict';

function money(v) {
  const n = Number(String(v ?? '').replace(/[^0-9.]/g, ''));
  return Number.isFinite(n) ? n : 0;
}

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.toISOString();
}

async function adminSummary(db) {
  const locations = await db.collection('locations').find().sort({ id: 1 }).toArray();
  const sims = await db.collection('sims').find().toArray();
  const cbc = await db.collection('cbc').find().toArray();
  const ctopup = await db.collection('ctopup').find().toArray();
  const today = startOfToday();

  const byId = {};
  for (const loc of locations) {
    byId[loc.id] = {
      id: Number(loc.id),
      name: loc.name || '',
      email: loc.email || '',
      sims: 0,
      newUsersToday: 0,
      cbcCount: 0,
      cbcAmount: 0,
      ctopupCount: 0,
      ctopupAmount: 0,
    };
  }

  function bucket(locationId) {
    const id = Number(locationId) || 0;
    if (!byId[id]) {
      byId[id] = {
        id,
        name: 'Unknown',
        email: '',
        sims: 0,
        newUsersToday: 0,
        cbcCount: 0,
        cbcAmount: 0,
        ctopupCount: 0,
        ctopupAmount: 0,
      };
    }
    return byId[id];
  }

  for (const r of sims) {
    const b = bucket(r.locationId);
    b.sims += 1;
    if (r.createdAt && String(r.createdAt) >= today) b.newUsersToday += 1;
  }
  for (const r of cbc) {
    const b = bucket(r.locationId);
    b.cbcCount += 1;
    b.cbcAmount += money(r.amount);
  }
  for (const r of ctopup) {
    const b = bucket(r.locationId);
    b.ctopupCount += 1;
    b.ctopupAmount += money(r.amount);
  }

  const list = Object.values(byId).sort((a, b) => a.id - b.id);
  const totals = list.reduce(
    (a, b) => ({
      sims: a.sims + b.sims,
      newUsersToday: a.newUsersToday + b.newUsersToday,
      cbcCount: a.cbcCount + b.cbcCount,
      cbcAmount: a.cbcAmount + b.cbcAmount,
      ctopupCount: a.ctopupCount + b.ctopupCount,
      ctopupAmount: a.ctopupAmount + b.ctopupAmount,
    }),
    { sims: 0, newUsersToday: 0, cbcCount: 0, cbcAmount: 0, ctopupCount: 0, ctopupAmount: 0 },
  );

  return {
    locations: locations.length,
    totals,
    byLocation: list,
  };
}

module.exports = { adminSummary, money };
