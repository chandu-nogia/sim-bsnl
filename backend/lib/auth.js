'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { nextId } = require('./ids');
const { logActivity } = require('./activity');
const rbac = require('./rbac');

const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || 'chandu@gmail.com').trim().toLowerCase();
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'chandu@khatu20';
const EMPLOYEE_EMAIL = (process.env.EMPLOYEE_EMAIL || 'chandu20@gmail.com').trim().toLowerCase();
const EMPLOYEE_PASSWORD = process.env.EMPLOYEE_PASSWORD || 'chandu@20khatu';
const DEFAULT_LOCATION = process.env.DEFAULT_LOCATION_NAME || 'Khatu Shyam Ji';
const OLD_KHATU_EMAILS = ['csckhatu@gmail.com'];

function authSecret() {
  return process.env.AUTH_SECRET || 'bsnl-sim-portal-change-me';
}

function assignedOf(user) {
  if (!user) return [];
  const fromArr = Array.isArray(user.assignedLocations)
    ? user.assignedLocations.map((v) => Number(v)).filter(Boolean)
    : [];
  const one = Number(user.locationId);
  return [...new Set([...fromArr, ...(one ? [one] : [])])];
}

function publicUser(user) {
  const assigned = user.role === 'admin' ? [] : assignedOf(user);
  return {
    id: user.id ? Number(user.id) : null,
    email: user.email,
    role: user.role,
    name: user.name || '',
    status: user.status === 'inactive' ? 'inactive' : 'active',
    locationId: assigned[0] || (user.locationId ? Number(user.locationId) : null),
    locationName: user.locationName || '',
    assignedLocations: assigned,
  };
}

function publicLocation(row) {
  return {
    id: Number(row.id),
    name: row.name || '',
    code: row.code || '',
    address: row.address || '',
    status: row.status === 'inactive' ? 'inactive' : 'active',
    email: row.email || '',
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
  };
}

function codeFromName(name) {
  const clean = String(name || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '')
    .slice(0, 10);
  return clean || 'LOC';
}

async function seedUsers(db) {
  const locCol = db.collection('locations');
  let khatu = await locCol.findOne({
    $or: [
      { name: DEFAULT_LOCATION },
      { name: 'Khatu' },
      { code: 'KHATU' },
      { email: EMPLOYEE_EMAIL },
      { email: { $in: OLD_KHATU_EMAILS } },
    ],
  });
  const now = new Date().toISOString();
  if (!khatu) {
    const id = await nextId(db, 'locations');
    khatu = {
      id,
      name: DEFAULT_LOCATION,
      code: 'KHATU',
      address: '',
      status: 'active',
      email: EMPLOYEE_EMAIL,
      createdAt: now,
      updatedAt: now,
    };
    await locCol.insertOne(khatu);
  } else {
    await locCol.updateOne(
      { id: khatu.id },
      {
        $set: {
          name: DEFAULT_LOCATION,
          code: khatu.code || 'KHATU',
          status: khatu.status || 'active',
          email: EMPLOYEE_EMAIL,
          updatedAt: now,
        },
      },
    );
    khatu.name = DEFAULT_LOCATION;
    khatu.code = khatu.code || 'KHATU';
    khatu.email = EMPLOYEE_EMAIL;
  }

  const users = db.collection('users');
  let adminId = (await users.findOne({ email: ADMIN_EMAIL }))?.id;
  if (!adminId) adminId = await nextId(db, 'users');
  await users.updateOne(
    { email: ADMIN_EMAIL },
    {
      $set: {
        id: adminId,
        email: ADMIN_EMAIL,
        passwordHash: bcrypt.hashSync(ADMIN_PASSWORD, 10),
        role: 'admin',
        name: 'Admin',
        locationId: null,
        locationName: '',
        assignedLocations: [],
        status: 'active',
        updatedAt: now,
      },
      $setOnInsert: { createdAt: now },
    },
    { upsert: true },
  );

  await users.deleteMany({
    email: { $in: OLD_KHATU_EMAILS },
    role: 'employee',
  });

  const locId = Number(khatu.id);
  let empId = (await users.findOne({ email: EMPLOYEE_EMAIL }))?.id;
  if (!empId) empId = await nextId(db, 'users');
  await users.updateOne(
    { email: EMPLOYEE_EMAIL },
    {
      $set: {
        id: empId,
        email: EMPLOYEE_EMAIL,
        passwordHash: bcrypt.hashSync(EMPLOYEE_PASSWORD, 10),
        role: 'employee',
        name: 'Khatu Employee',
        locationId: locId,
        locationName: khatu.name,
        assignedLocations: [locId],
        status: 'active',
        updatedAt: now,
      },
      $setOnInsert: { createdAt: now },
    },
    { upsert: true },
  );

  const others = await users.find({ role: 'employee', email: { $ne: EMPLOYEE_EMAIL } }).toArray();
  for (const u of others) {
    const assigned = assignedOf(u);
    const patch = {
      assignedLocations: assigned.length ? assigned : (u.locationId ? [Number(u.locationId)] : []),
      status: u.status === 'inactive' ? 'inactive' : 'active',
    };
    if (!u.id) patch.id = await nextId(db, 'users');
    await users.updateOne({ email: u.email }, { $set: patch });
  }

  for (const col of ['sims', 'cbc', 'ctopup']) {
    await db.collection(col).updateMany(
      {
        $or: [
          { locationId: { $exists: false } },
          { locationId: null },
          { locationId: 0 },
          { locationName: 'Khatu' },
          { locationName: DEFAULT_LOCATION },
          { locationId: locId },
        ],
      },
      { $set: { locationId: locId, locationName: khatu.name } },
    );
  }
}

function signToken(user) {
  const assigned = user.role === 'admin' ? [] : assignedOf(user);
  return jwt.sign(
    {
      id: user.id ? Number(user.id) : null,
      email: user.email,
      role: user.role,
      name: user.name || '',
      status: user.status === 'inactive' ? 'inactive' : 'active',
      locationId: assigned[0] || (user.locationId ? Number(user.locationId) : null),
      locationName: user.locationName || '',
      assignedLocations: assigned,
    },
    authSecret(),
    { expiresIn: '30d' },
  );
}

function readToken(req) {
  const h = String(req.headers.authorization || '');
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  try {
    return jwt.verify(m[1].trim(), authSecret());
  } catch {
    return null;
  }
}

async function login(db, body) {
  const email = String(body?.email || '').trim().toLowerCase();
  const password = String(body?.password || '');
  if (!email || !password) {
    return { status: 400, json: { ok: false, error: 'Email aur password likho' } };
  }
  const user = await db.collection('users').findOne({ email });
  if (!user || !bcrypt.compareSync(password, user.passwordHash)) {
    return { status: 401, json: { ok: false, error: 'Galat email ya password' } };
  }
  if (user.status === 'inactive') {
    return { status: 403, json: { ok: false, error: 'Account deactivate hai. Admin se baat karo.' } };
  }
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'login',
    section: 'auth',
    locationId: user.locationId,
    locationName: user.locationName,
    detail: `${user.name || user.email} logged in`,
  });
  return {
    status: 200,
    json: {
      ok: true,
      token: signToken(user),
      user: publicUser(user),
    },
  };
}

function requireUser(req, res, next) {
  const user = readToken(req);
  if (!user) {
    return res.status(401).json({ ok: false, error: 'Login karo' });
  }
  if (user.status === 'inactive') {
    return res.status(403).json({ ok: false, error: 'Account deactivate hai' });
  }
  req.user = user;
  next();
}

function requireAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({ ok: false, error: 'Login karo' });
  }
  if (req.user.role !== 'admin') {
    return res.status(403).json({ ok: false, error: 'Sirf admin ye kaam kar sakta hai' });
  }
  next();
}

const listScope = rbac.listScope;
const writeScope = rbac.writeScope;
const assertRowLocation = rbac.assertRowLocation;

async function listLocations(db, user) {
  const ids = rbac.assignedIds(user);
  const q = ids === null ? {} : { id: { $in: ids } };
  const rows = await db.collection('locations').find(q).sort({ id: 1 }).toArray();
  return rows.map(publicLocation);
}

async function addLocation(db, user, body) {
  const name = String(body?.name ?? '').trim();
  const code = String(body?.code ?? '').trim().toUpperCase() || codeFromName(name);
  const address = String(body?.address ?? '').trim();
  const status = body?.status === 'inactive' ? 'inactive' : 'active';
  if (!name) return { status: 400, json: { ok: false, error: 'Jagah ka naam likho' } };
  const dup = await db.collection('locations').findOne({
    $or: [{ name }, { code }],
  });
  if (dup) return { status: 400, json: { ok: false, error: 'Ye naam/code pehle se hai' } };
  const id = await nextId(db, 'locations');
  const now = new Date().toISOString();
  const loc = { id, name, code, address, status, createdAt: now, updatedAt: now };
  await db.collection('locations').insertOne(loc);

  const empEmail = String(body?.email ?? '').trim().toLowerCase();
  const empPass = String(body?.password ?? '');
  if (empEmail && empPass.length >= 4) {
    const exists = await db.collection('users').findOne({ email: empEmail });
    if (exists) return { status: 400, json: { ok: false, error: 'Ye employee email pehle se hai' } };
    const uid = await nextId(db, 'users');
    await db.collection('users').insertOne({
      id: uid,
      email: empEmail,
      passwordHash: bcrypt.hashSync(empPass, 10),
      role: 'employee',
      name: String(body?.employeeName || name).trim(),
      assignedLocations: [id],
      locationId: id,
      locationName: name,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
  }

  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'add',
    section: 'location',
    locationId: id,
    locationName: name,
    detail: `${user.name || user.email} created new location ${name}`,
  });
  return { status: 200, json: { ok: true, location: publicLocation(loc) } };
}

async function updateLocation(db, user, idRaw, body) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const loc = await db.collection('locations').findOne({ id });
  if (!loc) return { status: 404, json: { ok: false, error: 'Jagah nahi mili' } };
  const name = String(body?.name ?? loc.name).trim() || loc.name;
  const code = String(body?.code ?? loc.code ?? '').trim().toUpperCase() || loc.code || codeFromName(name);
  const address = body?.address != null ? String(body.address).trim() : (loc.address || '');
  const status = body?.status === 'inactive' ? 'inactive' : body?.status === 'active' ? 'active' : (loc.status || 'active');
  const now = new Date().toISOString();
  await db.collection('locations').updateOne({ id }, { $set: { name, code, address, status, updatedAt: now } });
  await db.collection('sims').updateMany({ locationId: id }, { $set: { locationName: name } });
  await db.collection('cbc').updateMany({ locationId: id }, { $set: { locationName: name } });
  await db.collection('ctopup').updateMany({ locationId: id }, { $set: { locationName: name } });
  await db.collection('users').updateMany(
    { assignedLocations: id },
    { $set: { locationName: name } },
  );
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'update',
    section: 'location',
    locationId: id,
    locationName: name,
    detail: `${user.name || user.email} updated location ${name}`,
  });
  return { status: 200, json: { ok: true, location: publicLocation({ ...loc, name, code, address, status, updatedAt: now }) } };
}

async function deleteLocation(db, user, idRaw) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const loc = await db.collection('locations').findOne({ id });
  if (!loc) return { status: 404, json: { ok: false, error: 'Jagah nahi mili' } };
  await db.collection('locations').deleteOne({ id });
  await db.collection('users').updateMany(
    { assignedLocations: id, role: 'employee' },
    { $pull: { assignedLocations: id } },
  );
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'delete',
    section: 'location',
    locationId: id,
    locationName: loc.name,
    detail: `${user.name || user.email} deleted location ${loc.name} (records rehte hain)`,
  });
  return { status: 200, json: { ok: true } };
}

async function locationNameOf(db, locationId) {
  const loc = await db.collection('locations').findOne({ id: Number(locationId) });
  return loc?.name || '';
}

module.exports = {
  seedUsers,
  login,
  requireUser,
  requireAdmin,
  publicUser,
  publicLocation,
  listScope,
  writeScope,
  assertRowLocation,
  listLocations,
  addLocation,
  updateLocation,
  deleteLocation,
  locationNameOf,
  signToken,
};
