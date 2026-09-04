'use strict';

const { assignedIds } = require('./rbac');
const { withAlive } = require('./alive');

function locFilter(user) {
  const ids = assignedIds(user);
  if (ids === null) return {};
  return { locationId: { $in: ids.length ? ids : [-1] } };
}

function note({ id, tone, title, from, reason, at, locationName, section }) {
  return {
    id,
    tone,
    title,
    from: from || 'System',
    reason: reason || '',
    at: at || '',
    locationName: locationName || '',
    section: section || '',
  };
}

function who(row) {
  return row.name || row.email || row.createdBy || 'Unknown';
}

function whyActivity(row) {
  if (row.detail) return row.detail;
  const act = row.action || 'action';
  const sec = row.section || 'record';
  return `${who(row)} ${act} on ${sec}`;
}

async function listNotifications(db, user) {
  const locQ = locFilter(user);
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const actQ = { at: { $gte: since }, action: { $ne: 'login' } };
  if (locQ.locationId) actQ.locationId = locQ.locationId;

  const [activity, pendingTop, failedTop, users] = await Promise.all([
    db.collection('activity').find(actQ).sort({ id: -1 }).limit(40).toArray(),
    db.collection('ctopup').find(withAlive({ ...locQ, status: 'Pending' })).sort({ id: -1 }).limit(15).toArray(),
    db.collection('ctopup').find(withAlive({ ...locQ, status: 'Failed' })).sort({ id: -1 }).limit(15).toArray(),
    db.collection('users').find({}, { projection: { email: 1, name: 1 } }).toArray(),
  ]);
  const names = {};
  for (const u of users) names[String(u.email || '').toLowerCase()] = u.name || u.email;

  const rows = [];
  const seen = new Set();

  function push(item) {
    if (!item.id || seen.has(item.id)) return;
    seen.add(item.id);
    rows.push(item);
  }

  for (const r of pendingTop) {
    const email = String(r.createdBy || '').toLowerCase();
    push(note({
      id: `pending-${r.id}`,
      tone: 'warn',
      title: 'C-TopUp pending',
      from: names[email] || r.createdBy || 'Unknown',
      reason: `${r.name || r.number || `Record #${r.id}`} ka payment pending hai${r.amount ? ` (₹${r.amount})` : ''}${r.locationName ? ` — ${r.locationName}` : ''}`,
      at: r.updatedAt || r.createdAt || '',
      locationName: r.locationName || '',
      section: 'ctopup',
    }));
  }
  for (const r of failedTop) {
    const email = String(r.createdBy || '').toLowerCase();
    push(note({
      id: `failed-${r.id}`,
      tone: 'danger',
      title: 'C-TopUp failed',
      from: names[email] || r.createdBy || 'Unknown',
      reason: `${r.name || r.number || `Record #${r.id}`} ka payment fail hua${r.amount ? ` (₹${r.amount})` : ''}${r.note ? ` — ${r.note}` : ''}${r.locationName ? ` — ${r.locationName}` : ''}`,
      at: r.updatedAt || r.createdAt || '',
      locationName: r.locationName || '',
      section: 'ctopup',
    }));
  }
  for (const r of activity) {
    const action = String(r.action || '');
    const tone = action === 'login-fail' || action === 'delete' ? 'danger'
      : action.includes('fail') || /password reset/i.test(String(r.detail || '')) ? 'warn'
        : 'info';
    const title = action === 'login-fail' ? 'Failed login'
      : /password reset/i.test(String(r.detail || '')) ? 'Password reset request'
        : action === 'delete' ? 'Record deleted'
          : action === 'add' ? 'New record'
            : action === 'update' ? 'Record updated'
              : action === 'restore' ? 'Record restored'
                : (r.section || 'Activity');
    push(note({
      id: `act-${r.id}`,
      tone,
      title,
      from: who(r),
      reason: whyActivity(r),
      at: r.at || '',
      locationName: r.locationName || '',
      section: r.section === 'auth' ? (action === 'login-fail' ? 'activity' : 'employees') : (r.section || 'activity'),
    }));
  }

  rows.sort((a, b) => String(b.at).localeCompare(String(a.at)));
  return { status: 200, json: { ok: true, rows: rows.slice(0, 50), total: rows.length } };
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
      version: 'locations-8',
      counts: { users, locations, sims, cbc, ctopup },
      lastActivity: activity[0]?.at || '',
    },
  };
}

module.exports = { listNotifications, systemHealth };
