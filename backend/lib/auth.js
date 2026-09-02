'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { nextId } = require('./ids');
const { logActivity } = require('./activity');

const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || 'chandu@gmail.com').trim().toLowerCase();
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'chandu@khatu20';
const EMPLOYEE_EMAIL = (process.env.EMPLOYEE_EMAIL || 'chandu20@gmail.com').trim().toLowerCase();
const EMPLOYEE_PASSWORD = process.env.EMPLOYEE_PASSWORD || 'chandu@20khatu';
const DEFAULT_LOCATION = process.env.DEFAULT_LOCATION_NAME || 'Khatu';
const OLD_KHATU_EMAILS = ['csckhatu@gmail.com'];

function authSecret() {
  return process.env.AUTH_SECRET || 'bsnl-sim-portal-change-me';
}

function publicUser(user) {
  return {
    email: user.email,
    role: user.role,
    name: user.name || '',
    locationId: user.locationId ? Number(user.locationId) : null,
    locationName: user.locationName || '',
  };
}

function publicLocation(row) {
  return {
    id: Number(row.id),
    name: row.name || '',
    email: row.email || '',
    createdAt: row.createdAt || '',
  };
}

async function seedUsers(db) {
  const locCol = db.collection('locations');
  let khatu = await locCol.findOne({
    $or: [
      { name: DEFAULT_LOCATION },
      { email: EMPLOYEE_EMAIL },
      { email: { $in: OLD_KHATU_EMAILS } },
    ],
  });
  if (!khatu) {
    const id = await nextId(db, 'locations');
    khatu = {
      id,
      name: DEFAULT_LOCATION,
      email: EMPLOYEE_EMAIL,
      createdAt: new Date().toISOString(),
    };
    await locCol.insertOne(khatu);
  } else {
    await locCol.updateOne(
      { id: khatu.id },
      { $set: { name: DEFAULT_LOCATION, email: EMPLOYEE_EMAIL } },
    );
    khatu.name = DEFAULT_LOCATION;
    khatu.email = EMPLOYEE_EMAIL;
  }

  const users = db.collection('users');
  await users.updateOne(
    { email: ADMIN_EMAIL },
    {
      $set: {
        email: ADMIN_EMAIL,
        passwordHash: bcrypt.hashSync(ADMIN_PASSWORD, 10),
        role: 'admin',
        name: 'Admin',
        locationId: null,
        locationName: '',
      },
    },
    { upsert: true },
  );

  await users.deleteMany({
    email: { $in: OLD_KHATU_EMAILS },
    role: 'employee',
  });

  await users.updateOne(
    { email: EMPLOYEE_EMAIL },
    {
      $set: {
        email: EMPLOYEE_EMAIL,
        passwordHash: bcrypt.hashSync(EMPLOYEE_PASSWORD, 10),
        role: 'employee',
        name: DEFAULT_LOCATION,
        locationId: Number(khatu.id),
        locationName: khatu.name,
      },
    },
    { upsert: true },
  );

  const locId = Number(khatu.id);
  for (const col of ['sims', 'cbc', 'ctopup']) {
    await db.collection(col).updateMany(
      {
        $or: [
          { locationId: { $exists: false } },
          { locationId: null },
          { locationId: 0 },
          { locationName: DEFAULT_LOCATION },
          { locationId: locId },
        ],
      },
      { $set: { locationId: locId, locationName: khatu.name } },
    );
  }
}

function signToken(user) {
  return jwt.sign(
    {
      email: user.email,
      role: user.role,
      name: user.name || '',
      locationId: user.locationId ? Number(user.locationId) : null,
      locationName: user.locationName || '',
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

function listScope(req) {
  if (req.user.role === 'employee') {
    const locationId = Number(req.user.locationId);
    if (!locationId) return { error: 'Is account ki jagah nahi mili', status: 403 };
    return { locationId };
  }
  const raw = req.query?.locationId;
  if (raw == null || String(raw).trim() === '') return {};
  const locationId = Number.parseInt(String(raw), 10);
  if (!locationId) return { error: 'Galat jagah', status: 400 };
  return { locationId };
}

function writeScope(req, body) {
  if (req.user.role === 'employee') {
    const locationId = Number(req.user.locationId);
    const locationName = req.user.locationName || '';
    if (!locationId) return { error: 'Is account ki jagah nahi mili', status: 403 };
    return { locationId, locationName };
  }
  const raw = body?.locationId ?? req.query?.locationId;
  const locationId = Number.parseInt(String(raw ?? ''), 10);
  if (!locationId) return { error: 'Jagah choose karo', status: 400 };
  return { locationId, locationName: String(body?.locationName || req.user.locationName || '').trim() };
}

async function assertRowLocation(req, row) {
  if (req.user.role !== 'employee') return null;
  if (Number(row.locationId) !== Number(req.user.locationId)) {
    return { status: 403, json: { ok: false, error: 'Ye entry dusri jagah ki hai' } };
  }
  return null;
}

async function listLocations(db, user) {
  const q = user.role === 'admin' ? {} : { id: Number(user.locationId) };
  const rows = await db.collection('locations').find(q).sort({ id: 1 }).toArray();
  return rows.map(publicLocation);
}

async function addLocation(db, user, body) {
  const name = String(body?.name ?? '').trim();
  const email = String(body?.email ?? '').trim().toLowerCase();
  const password = String(body?.password ?? '');
  if (!name) return { status: 400, json: { ok: false, error: 'Jagah ka naam likho' } };
  if (!email || !email.includes('@')) return { status: 400, json: { ok: false, error: 'Jagah ki email / ID likho' } };
  if (password.length < 4) return { status: 400, json: { ok: false, error: 'Password kam se kam 4 character' } };
  const exists = await db.collection('users').findOne({ email });
  if (exists) return { status: 400, json: { ok: false, error: 'Ye email pehle se hai' } };
  const id = await nextId(db, 'locations');
  const loc = { id, name, email, createdAt: new Date().toISOString() };
  await db.collection('locations').insertOne(loc);
  await db.collection('users').insertOne({
    email,
    passwordHash: bcrypt.hashSync(password, 10),
    role: 'employee',
    name,
    locationId: id,
    locationName: name,
  });
  await logActivity(db, {
    email: user.email,
    role: user.role,
    action: 'add',
    section: 'location',
    locationId: id,
    locationName: name,
    detail: `${name} jagah add (${email})`,
  });
  return { status: 200, json: { ok: true, location: publicLocation(loc) } };
}

async function updateLocation(db, user, idRaw, body) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const loc = await db.collection('locations').findOne({ id });
  if (!loc) return { status: 404, json: { ok: false, error: 'Jagah nahi mili' } };
  const name = String(body?.name ?? loc.name).trim() || loc.name;
  const email = String(body?.email ?? loc.email).trim().toLowerCase() || loc.email;
  const password = String(body?.password ?? '');
  const taken = await db.collection('users').findOne({ email, locationId: { $ne: id } });
  const other = await db.collection('users').findOne({ email, role: 'admin' });
  if (other || (taken && Number(taken.locationId) !== id)) {
    return { status: 400, json: { ok: false, error: 'Ye email dusre account ki hai' } };
  }
  await db.collection('locations').updateOne({ id }, { $set: { name, email } });
  const setUser = { email, name, locationName: name, locationId: id, role: 'employee' };
  if (password.length >= 4) setUser.passwordHash = bcrypt.hashSync(password, 10);
  await db.collection('users').updateOne(
    { $or: [{ locationId: id }, { email: loc.email }] },
    { $set: setUser },
    { upsert: true },
  );
  await db.collection('sims').updateMany({ locationId: id }, { $set: { locationName: name } });
  await db.collection('cbc').updateMany({ locationId: id }, { $set: { locationName: name } });
  await db.collection('ctopup').updateMany({ locationId: id }, { $set: { locationName: name } });
  await logActivity(db, {
    email: user.email,
    role: user.role,
    action: 'update',
    section: 'location',
    locationId: id,
    locationName: name,
    detail: `${name} jagah update`,
  });
  return { status: 200, json: { ok: true, location: publicLocation({ ...loc, name, email }) } };
}

async function deleteLocation(db, user, idRaw) {
  const id = Number.parseInt(String(idRaw), 10);
  if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
  const loc = await db.collection('locations').findOne({ id });
  if (!loc) return { status: 404, json: { ok: false, error: 'Jagah nahi mili' } };
  await db.collection('locations').deleteOne({ id });
  await db.collection('users').deleteMany({ locationId: id, role: 'employee' });
  await logActivity(db, {
    email: user.email,
    role: user.role,
    action: 'delete',
    section: 'location',
    locationId: id,
    locationName: loc.name,
    detail: `${loc.name} jagah delete (data rehta hai)`,
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
