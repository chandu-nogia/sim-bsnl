'use strict';

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || 'chandu@gmail.com').trim().toLowerCase();
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'chandu@khatu';
const EMPLOYEE_EMAIL = (process.env.EMPLOYEE_EMAIL || 'csckhatu@gmail.com').trim().toLowerCase();
const EMPLOYEE_PASSWORD = process.env.EMPLOYEE_PASSWORD || 'csckhatu@25';

function authSecret() {
  return process.env.AUTH_SECRET || 'bsnl-sim-portal-change-me';
}

function publicUser(user) {
  return {
    email: user.email,
    role: user.role,
    name: user.name || '',
  };
}

async function seedUsers(db) {
  const col = db.collection('users');
  const specs = [
    {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      role: 'admin',
      name: 'Admin',
    },
    {
      email: EMPLOYEE_EMAIL,
      password: EMPLOYEE_PASSWORD,
      role: 'employee',
      name: 'Employee',
    },
  ];
  for (const s of specs) {
    const passwordHash = bcrypt.hashSync(s.password, 10);
    await col.updateOne(
      { email: s.email },
      {
        $set: {
          email: s.email,
          passwordHash,
          role: s.role,
          name: s.name,
        },
      },
      { upsert: true },
    );
  }
}

function signToken(user) {
  return jwt.sign(
    { email: user.email, role: user.role, name: user.name || '' },
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
    return res.status(403).json({ ok: false, error: 'Sirf admin add/edit/delete kar sakta hai' });
  }
  next();
}

module.exports = { seedUsers, login, requireUser, requireAdmin, publicUser };
