'use strict';

const bcrypt = require('bcryptjs');
const { validatePassword } = require('./password');
const { logActivity } = require('./activity');
const { publicUser, signToken } = require('./auth');

async function changePassword(db, user, body) {
  const current = String(body?.current || body?.oldPassword || '');
  const next = String(body?.next || body?.password || body?.newPassword || '');
  const err = validatePassword(next);
  if (err) return { status: 400, json: { ok: false, error: err } };
  const row = await db.collection('users').findOne({ email: user.email });
  if (!row) return { status: 401, json: { ok: false, error: 'Login karo' } };
  if (!bcrypt.compareSync(current, row.passwordHash)) {
    return { status: 400, json: { ok: false, error: 'Purana password galat hai' } };
  }
  await db.collection('users').updateOne(
    { email: user.email },
    { $set: { passwordHash: bcrypt.hashSync(next, 10), updatedAt: new Date().toISOString() } },
  );
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name: user.name,
    action: 'update',
    section: 'auth',
    locationId: user.locationId,
    locationName: user.locationName,
    detail: `${user.name || user.email} changed own password`,
  });
  return { status: 200, json: { ok: true } };
}

async function updateMe(db, user, body) {
  const name = String(body?.name ?? '').trim();
  if (!name) return { status: 400, json: { ok: false, error: 'Naam likho' } };
  const now = new Date().toISOString();
  await db.collection('users').updateOne(
    { email: user.email },
    { $set: { name, updatedAt: now } },
  );
  const row = await db.collection('users').findOne({ email: user.email });
  await logActivity(db, {
    email: user.email,
    role: user.role,
    name,
    action: 'update',
    section: 'auth',
    locationId: user.locationId,
    locationName: user.locationName,
    detail: `${name} updated profile name`,
  });
  return { status: 200, json: { ok: true, user: publicUser(row), token: signToken(row) } };
}

async function forgotPassword(db, body) {
  const email = String(body?.email || '').trim().toLowerCase();
  if (!email || !email.includes('@')) {
    return { status: 400, json: { ok: false, error: 'Email likho' } };
  }
  const user = await db.collection('users').findOne({ email });
  if (user) {
    await logActivity(db, {
      email: user.email,
      role: user.role,
      name: user.name,
      action: 'update',
      section: 'auth',
      locationId: user.locationId,
      locationName: user.locationName,
      detail: `${user.name || user.email} requested password reset`,
    });
  }
  return {
    status: 200,
    json: {
      ok: true,
      message: 'Agar ye account hai to admin ko reset request mil gayi. Admin se naya password maango.',
    },
  };
}

module.exports = { changePassword, updateMe, forgotPassword };
