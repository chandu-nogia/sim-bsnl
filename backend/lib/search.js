'use strict';

const { assignedIds } = require('./rbac');
const { withAlive } = require('./alive');

function locFilter(user) {
  const ids = assignedIds(user);
  if (ids === null) return {};
  return { locationId: { $in: ids.length ? ids : [-1] } };
}

function rx(q) {
  return { $regex: String(q).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
}

function hit(id, title, subtitle, section, extra = {}) {
  return { id, title, subtitle, section, ...extra };
}

async function globalSearch(db, user, raw) {
  const q = String(raw || '').trim();
  if (q.length < 2) {
    return { status: 200, json: { ok: true, q, groups: { employees: [], locations: [], sims: [], cbc: [], ctopup: [] } } };
  }
  const scope = locFilter(user);
  const alive = withAlive(scope);
  const text = rx(q);
  const asId = Number.parseInt(q, 10) || 0;
  const jobs = [
    db.collection('locations').find({
      ...(user.role === 'admin' ? {} : { id: { $in: assignedIds(user) || [-1] } }),
      $or: [{ name: text }, { code: text }, ...(asId ? [{ id: asId }] : [])],
    }).limit(8).toArray(),
    db.collection('sims').find({ ...alive, $or: [{ name: text }, { mobile: text }, { sim: text }, { last6: text }, ...(asId ? [{ id: asId }] : [])] }).limit(8).toArray(),
    db.collection('cbc').find({ ...alive, $or: [{ name: text }, { mobile: text }, { transactionId: text }, ...(asId ? [{ id: asId }] : [])] }).limit(8).toArray(),
    db.collection('ctopup').find({ ...alive, $or: [{ name: text }, { number: text }, { transactionId: text }, ...(asId ? [{ id: asId }] : [])] }).limit(8).toArray(),
  ];
  if (user.role === 'admin') {
    jobs.unshift(
      db.collection('users').find({
        role: { $ne: 'x' },
        $or: [{ name: text }, { email: text }, { mobile: text }, ...(asId ? [{ id: asId }] : [])],
      }).limit(8).toArray(),
    );
  } else {
    jobs.unshift(Promise.resolve([]));
  }
  const [employees, locations, sims, cbc, ctopup] = await Promise.all(jobs);
  return {
    status: 200,
    json: {
      ok: true,
      q,
      groups: {
        employees: employees.map((r) => hit(r.id, r.name || r.email, r.email, 'employees', { email: r.email, locationId: r.locationId, locationName: r.locationName })),
        locations: locations.map((r) => hit(r.id, r.name, r.code || r.status, 'locations', { locationId: r.id })),
        sims: sims.map((r) => hit(r.id, r.name, `${r.mobile || ''} · ${r.sim || ''}`, 'portal', { locationId: r.locationId, locationName: r.locationName })),
        cbc: cbc.map((r) => hit(r.id, r.name, `${r.mobile || ''} · ${r.transactionId || ''}`, 'cbc', { locationId: r.locationId, locationName: r.locationName })),
        ctopup: ctopup.map((r) => hit(r.id, r.name, `${r.number || ''} · ${r.transactionId || ''}`, 'ctopup', { locationId: r.locationId, locationName: r.locationName })),
      },
    },
  };
}

module.exports = { globalSearch };
