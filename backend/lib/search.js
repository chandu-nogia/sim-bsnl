'use strict';

const { withAlive } = require('./alive');
const { khatuLocation, khatuQuery } = require('./site');

function rx(q) {
  return { $regex: String(q).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
}

function hit(id, title, subtitle, section) {
  return { id, title, subtitle, section };
}

async function globalSearch(db, _user, raw) {
  const q = String(raw || '').trim();
  if (q.length < 2) {
    return { status: 200, json: { ok: true, q, groups: { sims: [], cbc: [], ctopup: [] } } };
  }
  const loc = await khatuLocation(db);
  const alive = withAlive(loc ? khatuQuery(loc) : { locationId: 1 });
  const text = rx(q);
  const asId = Number.parseInt(q, 10) || 0;
  const [sims, cbc, ctopup] = await Promise.all([
    db.collection('sims').find({ ...alive, $or: [{ name: text }, { mobile: text }, { sim: text }, { last6: text }, ...(asId ? [{ id: asId }] : [])] }).limit(8).toArray(),
    db.collection('cbc').find({ ...alive, $or: [{ name: text }, { mobile: text }, { transactionId: text }, ...(asId ? [{ id: asId }] : [])] }).limit(8).toArray(),
    db.collection('ctopup').find({ ...alive, $or: [{ name: text }, { number: text }, { transactionId: text }, ...(asId ? [{ id: asId }] : [])] }).limit(8).toArray(),
  ]);
  return {
    status: 200,
    json: {
      ok: true,
      q,
      groups: {
        sims: sims.map((r) => hit(r.id, r.name, `${r.mobile || ''} · ${r.sim || ''}`, 'portal')),
        cbc: cbc.map((r) => hit(r.id, r.name, `${r.mobile || ''} · ${r.transactionId || ''}`, 'cbc')),
        ctopup: ctopup.map((r) => hit(r.id, r.name, `${r.number || ''} · ${r.transactionId || ''}`, 'ctopup')),
      },
    },
  };
}

module.exports = { globalSearch };
