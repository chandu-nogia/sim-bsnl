'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { nextId } = require('./ids');
const { logActivity } = require('./activity');
const rbac = require('./rbac');
const { getDb } = require('./db');
const { OWNER_EMAIL, OWNER_PASSWORD, LOCATION_NAME, isOwnerEmail, khatuLocation } = require('./site');

function authSecret() {
  const raw = String(process.env.AUTH_SECRET || '').trim();
  if (raw && raw !== 'bsnl-sim-portal-change-me' && raw.length >= 16) return raw;
  if (process.env.RENDER || process.env.NODE_ENV === 'production') {
    console.warn('AUTH_SECRET missing or weak. Set a 16+ character secret on Render.');
  }
  return raw || 'dev-only-change-AUTH_SECRET';
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
  const locId = Number(user.locationId) || (assignedOf(user)[0] || null);
  return {
    id: user.id ? Number(user.id) : null,
    email: user.email,
    role: 'owner',
    name: user.name || '',
    status: user.status === 'inactive' ? 'inactive' : 'active',
    locationId: locId,
    locationName: user.locationName || LOCATION_NAME,
    assignedLocations: locId ? [locId] : [],
  };
}

async function seedUsers(db) {
  const locCol = db.collection('locations');
  let khatu = await khatuLocation(db);
  const now = new Date().toISOString();
  if (!khatu) {
    const id = await nextId(db, 'locations');
    khatu = {
      id,
      name: LOCATION_NAME,
      code: 'KHATU',
      address: '',
      status: 'active',
      email: OWNER_EMAIL,
      createdAt: now,
      updatedAt: now,
    };
    await locCol.insertOne(khatu);
  } else {
    await locCol.updateOne(
      { id: khatu.id },
      {
        $set: {
          name: LOCATION_NAME,
          code: khatu.code || 'KHATU',
          status: khatu.status || 'active',
          email: OWNER_EMAIL,
          updatedAt: now,
        },
      },
    );
    khatu.name = LOCATION_NAME;
    khatu.code = khatu.code || 'KHATU';
    khatu.email = OWNER_EMAIL;
  }

  const users = db.collection('users');
  const locId = Number(khatu.id);
  const existing = await users.findOne({ email: OWNER_EMAIL });
  if (!existing) {
    const empId = await nextId(db, 'users');
    await users.insertOne({
      id: empId,
      email: OWNER_EMAIL,
      passwordHash: bcrypt.hashSync(OWNER_PASSWORD, 10),
      role: 'owner',
      name: 'Khatushyamji',
      locationId: locId,
      locationName: khatu.name,
      assignedLocations: [locId],
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
  } else {
    await users.updateOne(
      { email: OWNER_EMAIL },
      {
        $set: {
          role: 'owner',
          status: 'active',
          locationId: Number(existing.locationId) || locId,
          assignedLocations: [Number(existing.locationId) || locId],
          locationName: existing.locationName || khatu.name,
        },
      },
    );
  }

  for (const col of ['sims', 'cbc', 'ctopup']) {
    await db.collection(col).updateMany(
      {
        $or: [
          { locationId: { $exists: false } },
          { locationId: null },
          { locationId: 0 },
          { locationId: '' },
        ],
      },
      { $set: { locationId: locId, locationName: khatu.name } },
    );
  }
}

function signToken(user) {
  const locId = Number(user.locationId) || assignedOf(user)[0] || null;
  return jwt.sign(
    {
      id: user.id ? Number(user.id) : null,
      email: user.email,
      role: 'owner',
      name: user.name || '',
      status: user.status === 'inactive' ? 'inactive' : 'active',
      locationId: locId,
      locationName: user.locationName || LOCATION_NAME,
      assignedLocations: locId ? [locId] : [],
    },
    authSecret(),
    { expiresIn: process.env.JWT_EXPIRES || '24h' },
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

async function login(db, body, req) {
  const email = String(body?.email || '').trim().toLowerCase();
  const password = String(body?.password || '');
  const ip = String(req?.headers?.['x-forwarded-for'] || req?.socket?.remoteAddress || '')
    .split(',')[0]
    .trim();
  if (!email || !password) {
    return { status: 400, json: { ok: false, error: 'Email aur password likho' } };
  }
  const user = await db.collection('users').findOne({ email });
  if (!user || !bcrypt.compareSync(password, user.passwordHash)) {
    await logActivity(db, {
      email,
      role: user?.role || '',
      name: user?.name || '',
      action: 'login-fail',
      section: 'auth',
      locationId: user?.locationId,
      ip,
      detail: `Failed login for ${email}`,
    });
    return { status: 401, json: { ok: false, error: 'Galat email ya password' } };
  }
  if (user.status === 'inactive') {
    return { status: 403, json: { ok: false, error: 'Account deactivate hai.' } };
  }
  if (!isOwnerEmail(email)) {
    return { status: 401, json: { ok: false, error: 'Galat email ya password' } };
  }
  const khatu = await khatuLocation(db);
  const locId = Number(khatu?.id) || Number(user.locationId) || assignedOf(user)[0] || 0;
  user.locationId = locId;
  user.assignedLocations = locId ? [locId] : [];
  user.locationName = khatu?.name || user.locationName || LOCATION_NAME;
  user.role = 'owner';
  const now = new Date().toISOString();
  await db.collection('users').updateOne({ email: user.email }, { $set: { lastLogin: now } });
  user.lastLogin = now;
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'login',
    section: 'auth',
    locationId: user.locationId,
    locationName: user.locationName,
    ip,
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

async function requireUser(req, res, next) {
  const tokenUser = readToken(req);
  if (!tokenUser) {
    return res.status(401).json({ ok: false, error: 'Login karo' });
  }
  try {
    const db = await getDb();
    const row = await db.collection('users').findOne({ email: tokenUser.email });
    if (!row) {
      return res.status(401).json({ ok: false, error: 'Login karo' });
    }
    if (row.status === 'inactive') {
      return res.status(403).json({ ok: false, error: 'Account deactivate hai' });
    }
    if (!isOwnerEmail(row.email)) {
      return res.status(403).json({ ok: false, error: 'Login karo' });
    }
    const khatu = await khatuLocation(db);
    const locId = Number(khatu?.id) || Number(row.locationId) || assignedOf(row)[0] || 0;
    req.user = {
      id: row.id ? Number(row.id) : null,
      email: row.email,
      role: 'owner',
      name: row.name || '',
      status: 'active',
      locationId: locId,
      locationName: khatu?.name || row.locationName || LOCATION_NAME,
      assignedLocations: locId ? [locId] : [],
    };
    next();
  } catch (e) {
    next(e);
  }
}

const listScope = rbac.listScope;
const writeScope = rbac.writeScope;
const assertRowLocation = rbac.assertRowLocation;

async function locationNameOf(db, locationId) {
  const loc = await db.collection('locations').findOne({ id: Number(locationId) });
  return loc?.name || '';
}

module.exports = {
  seedUsers,
  login,
  requireUser,
  publicUser,
  listScope,
  writeScope,
  assertRowLocation,
  locationNameOf,
  signToken,
};
