'use strict';

const bcrypt = require('bcryptjs');
const { nextId } = require('./ids');
const { logActivity } = require('./activity');

function asIds(v) {
  if (!Array.isArray(v)) return [];
  return [...new Set(v.map((x) => Number(x)).filter(Boolean))];
}

function publicEmployee(row, locNames = {}) {
  const assigned = asIds(row.assignedLocations);
  return {
    id: row.id ? Number(row.id) : null,
    name: row.name || '',
    email: row.email || '',
    role: row.role || 'employee',
    assignedLocations: assigned,
    assignedLocationNames: assigned.map((id) => locNames[id] || `#${id}`),
    status: row.status === 'inactive' ? 'inactive' : 'active',
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
  };
}

async function locationNamesMap(db) {
  const rows = await db.collection('locations').find().toArray();
  const m = {};
  for (const r of rows) m[Number(r.id)] = r.name || '';
  return m;
}

async function listEmployees(db) {
  const names = await locationNamesMap(db);
  const rows = await db
    .collection('users')
    .find({ role: { $in: ['employee', 'admin'] } })
    .sort({ role: 1, email: 1 })
    .toArray();
  return rows.map((r) => publicEmployee(r, names));
}

async function addEmployee(db, actor, body) {
  const name = String(body?.name ?? '').trim();
  const email = String(body?.email ?? '').trim().toLowerCase();
  const password = String(body?.password ?? '');
  const assigned = asIds(body?.assignedLocations);
  const status = body?.status === 'inactive' ? 'inactive' : 'active';
  if (!name) return { status: 400, json: { ok: false, error: 'Naam likho' } };
  if (!email || !email.includes('@')) return { status: 400, json: { ok: false, error: 'Email likho' } };
  if (password.length < 4) return { status: 400, json: { ok: false, error: 'Password kam se kam 4 character' } };
  if (!assigned.length) return { status: 400, json: { ok: false, error: 'Kam se kam ek jagah assign karo' } };
  const exists = await db.collection('users').findOne({ email });
  if (exists) return { status: 400, json: { ok: false, error: 'Ye email pehle se hai' } };
  const locs = await db.collection('locations').find({ id: { $in: assigned } }).toArray();
  if (locs.length !== assigned.length) {
    return { status: 400, json: { ok: false, error: 'Koi jagah galat hai' } };
  }
  const id = await nextId(db, 'users');
  const now = new Date().toISOString();
  const first = locs[0];
  const row = {
    id,
    email,
    passwordHash: bcrypt.hashSync(password, 10),
    role: 'employee',
    name,
    assignedLocations: assigned,
    locationId: Number(first.id),
    locationName: first.name || '',
    status,
    createdAt: now,
    updatedAt: now,
  };
  await db.collection('users').insertOne(row);
  await logActivity(db, {
    email: actor.email,
    role: actor.role,
    name: actor.name,
    action: 'add',
    section: 'employee',
    locationId: first.id,
    locationName: first.name,
    detail: `${actor.name || actor.email} created employee ${name} (${email})`,
  });
  const names = await locationNamesMap(db);
  return { status: 200, json: { ok: true, employee: publicEmployee(row, names) } };
}

async function updateEmployee(db, actor, idRaw, body) {
  const emailKey = String(idRaw || '').trim().toLowerCase();
  const user = await db.collection('users').findOne({
    $or: [{ email: emailKey }, { id: Number.parseInt(emailKey, 10) || -1 }],
  });
  if (!user) return { status: 404, json: { ok: false, error: 'Employee nahi mila' } };
  if (user.role === 'admin' && actor.email !== user.email) {
    return { status: 403, json: { ok: false, error: 'Admin account yahan se nahi badlega' } };
  }
  const name = String(body?.name ?? user.name).trim() || user.name;
  const email = String(body?.email ?? user.email).trim().toLowerCase() || user.email;
  const status = body?.status === 'inactive' ? 'inactive' : body?.status === 'active' ? 'active' : (user.status || 'active');
  let assigned = body?.assignedLocations != null ? asIds(body.assignedLocations) : asIds(user.assignedLocations);
  if (user.role === 'employee' && !assigned.length) {
    return { status: 400, json: { ok: false, error: 'Kam se kam ek jagah assign karo' } };
  }
  if (email !== user.email) {
    const taken = await db.collection('users').findOne({ email });
    if (taken) return { status: 400, json: { ok: false, error: 'Ye email pehle se hai' } };
  }
  let locationId = user.locationId;
  let locationName = user.locationName;
  if (assigned.length) {
    const loc = await db.collection('locations').findOne({ id: assigned[0] });
    locationId = assigned[0];
    locationName = loc?.name || locationName;
  }
  const set = {
    name,
    email,
    status,
    assignedLocations: user.role === 'admin' ? [] : assigned,
    locationId: user.role === 'admin' ? null : locationId,
    locationName: user.role === 'admin' ? '' : locationName,
    updatedAt: new Date().toISOString(),
  };
  if (String(body?.password || '').length >= 4) {
    set.passwordHash = bcrypt.hashSync(String(body.password), 10);
  }
  await db.collection('users').updateOne({ email: user.email }, { $set: set });
  await logActivity(db, {
    email: actor.email,
    role: actor.role,
    name: actor.name,
    action: 'update',
    section: 'employee',
    locationId,
    locationName,
    detail: `${actor.name || actor.email} updated employee ${name}`,
  });
  const names = await locationNamesMap(db);
  return { status: 200, json: { ok: true, employee: publicEmployee({ ...user, ...set }, names) } };
}

async function resetPassword(db, actor, idRaw, body) {
  const password = String(body?.password ?? '');
  if (password.length < 4) return { status: 400, json: { ok: false, error: 'Naya password kam se kam 4 character' } };
  const emailKey = String(idRaw || '').trim().toLowerCase();
  const user = await db.collection('users').findOne({
    $or: [{ email: emailKey }, { id: Number.parseInt(emailKey, 10) || -1 }],
  });
  if (!user) return { status: 404, json: { ok: false, error: 'Employee nahi mila' } };
  await db.collection('users').updateOne(
    { email: user.email },
    { $set: { passwordHash: bcrypt.hashSync(password, 10), updatedAt: new Date().toISOString() } },
  );
  await logActivity(db, {
    email: actor.email,
    role: actor.role,
    name: actor.name,
    action: 'update',
    section: 'employee',
    detail: `${actor.name || actor.email} reset password for ${user.name || user.email}`,
  });
  return { status: 200, json: { ok: true } };
}

async function deleteEmployee(db, actor, idRaw) {
  const emailKey = String(idRaw || '').trim().toLowerCase();
  const user = await db.collection('users').findOne({
    $or: [{ email: emailKey }, { id: Number.parseInt(emailKey, 10) || -1 }],
  });
  if (!user) return { status: 404, json: { ok: false, error: 'Employee nahi mila' } };
  if (user.role === 'admin') return { status: 403, json: { ok: false, error: 'Admin delete nahi hoga' } };
  if (user.email === actor.email) return { status: 400, json: { ok: false, error: 'Khud ko delete nahi kar sakte' } };
  await db.collection('users').deleteOne({ email: user.email });
  await logActivity(db, {
    email: actor.email,
    role: actor.role,
    name: actor.name,
    action: 'delete',
    section: 'employee',
    detail: `${actor.name || actor.email} deleted employee ${user.name || user.email}`,
  });
  return { status: 200, json: { ok: true } };
}

module.exports = {
  publicEmployee,
  listEmployees,
  addEmployee,
  updateEmployee,
  resetPassword,
  deleteEmployee,
};
