'use strict';

const { assignedIds } = require('./rbac');
const { withAlive } = require('./alive');

async function listNotifications(db, user) {
  const ids = assignedIds(user);
  const locQ = ids === null ? {} : { locationId: { $in: ids.length ? ids : [-1] } };
  const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
  const [pendingTop, failedTop, pendingClose, lowStock, failLogins] = await Promise.all([
    db.collection('ctopup').countDocuments(withAlive({ ...locQ, status: 'Pending' })),
    db.collection('ctopup').countDocuments(withAlive({ ...locQ, status: 'Failed' })),
    db.collection('closing').countDocuments({ ...locQ, status: 'pending' }),
    db.collection('stock').find(locQ).toArray(),
    db.collection('activity').countDocuments({
      action: 'login-fail',
      at: { $gte: since },
      ...(ids === null ? {} : { locationId: { $in: ids.length ? ids : [-1] } }),
    }),
  ]);
  const rows = [];
  if (pendingTop) rows.push({ id: 'pending-top', tone: 'warn', title: `${pendingTop} C-TopUp pending`, section: 'ctopup' });
  if (failedTop) rows.push({ id: 'failed-top', tone: 'danger', title: `${failedTop} C-TopUp failed`, section: 'ctopup' });
  if (pendingClose) rows.push({ id: 'pending-close', tone: 'warn', title: `${pendingClose} daily closing pending review`, section: 'closing' });
  const low = lowStock.filter((s) => Number(s.qty || 0) <= Number(s.lowAt || 20));
  if (low.length) rows.push({ id: 'low-stock', tone: 'warn', title: `Low SIM stock at ${low.length} location(s)`, section: 'stock' });
  if (failLogins) rows.push({ id: 'login-fail', tone: 'danger', title: `${failLogins} failed logins (48h)`, section: 'activity' });
  if (user.role === 'admin') {
    const resets = await db.collection('activity').countDocuments({ section: 'auth', detail: { $regex: 'requested password reset', $options: 'i' }, at: { $gte: since } });
    if (resets) rows.push({ id: 'pw-reset', tone: 'info', title: `${resets} password reset request(s)`, section: 'employees' });
  }
  return { status: 200, json: { ok: true, rows, total: rows.length } };
}

async function systemHealth(db) {
  const started = Date.now();
  await db.command({ ping: 1 });
  const pingMs = Date.now() - started;
  const [users, locations, sims, cbc, ctopup, activity] = await Promise.all([
    db.collection('users').countDocuments(),
    db.collection('locations').countDocuments({ status: { $ne: 'inactive' } }),
    db.collection('sims').countDocuments(withAlive({})),
    db.collection('cbc').countDocuments(withAlive({})),
    db.collection('ctopup').countDocuments(withAlive({})),
    db.collection('activity').find().sort({ id: -1 }).limit(1).toArray(),
  ]);
  return {
    status: 200,
    json: {
      ok: true,
      mongo: 'connected',
      pingMs,
      version: 'locations-7',
      counts: { users, locations, sims, cbc, ctopup },
      lastActivity: activity[0]?.at || '',
    },
  };
}

module.exports = { listNotifications, systemHealth };
