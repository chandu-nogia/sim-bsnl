'use strict';

require('dotenv').config();

const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');

const { getDb } = require('./lib/db');
const { listSims, addSim, updateSim, deleteSim } = require('./lib/sims');
const {
  seedUsers,
  login,
  requireUser,
  requireAdmin,
  publicUser,
  signToken,
  listScope,
  writeScope,
  assertRowLocation,
  listLocations,
  addLocation,
  updateLocation,
  deleteLocation,
  locationNameOf,
} = require('./lib/auth');
const { cbc, ctopup } = require('./lib/records');
const { listActivity } = require('./lib/activity');
const { adminSummary, locationSummary } = require('./lib/summary');
const { listEmployees, employeeDetail, addEmployee, updateEmployee, resetPassword, deleteEmployee } = require('./lib/employees');
const { buildReport } = require('./lib/reports');
const { ensureIndexes } = require('./lib/indexes');
const { loginGuard, loginClear } = require('./lib/rate_limit');
const { changePassword, updateMe, forgotPassword } = require('./lib/account');
const { previewLocation } = require('./lib/location_resolve');
const { listDeleted, restoreRow, purgeRow } = require('./lib/recycle');
const { getStock, saveStock, listClosing, addClosing, reviewClosing, importRows, todayStats } = require('./lib/shop');
const { globalSearch } = require('./lib/search');
const { listNotifications, systemHealth } = require('./lib/ops');

const PORT = Number(process.env.PORT) || 5050;
const WEB_DIR = path.join(__dirname, '..', 'bsnl_sim_portal', 'build', 'web');

const app = express();
app.set('trust proxy', 1);

const extraOrigins = String(process.env.CORS_ORIGIN || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
function corsOrigin(origin, cb) {
  if (!origin) return cb(null, true);
  const allow = [
    'https://web-rosy-seven-32.vercel.app',
    'http://localhost:5050',
    'http://localhost:8080',
    'http://127.0.0.1:5050',
    'http://127.0.0.1:8080',
    ...extraOrigins,
  ];
  if (allow.includes(origin) || /\.vercel\.app$/.test(origin) || /localhost:\d+$/.test(origin)) {
    return cb(null, true);
  }
  return cb(null, false);
}
app.use(cors({
  origin: corsOrigin,
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Location-Id'],
}));
app.options('*', cors({ origin: corsOrigin, allowedHeaders: ['Content-Type', 'Authorization', 'X-Location-Id'] }));
app.use(express.json({ limit: '2mb' }));
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'same-origin');
  next();
});

function send(res, out) {
  res.status(out.status).json(out.json);
}

function scoped(req) {
  const s = listScope(req);
  if (s.error) return { ok: false, status: s.status || 400, error: s.error };
  return {
    ok: true,
    ...s,
    q: req.query?.q || req.query?.search || '',
    from: req.query?.from || '',
    to: req.query?.to || '',
    employee: req.query?.employee || '',
    status: req.query?.status || '',
    page: req.query?.page,
    limit: req.query?.limit,
  };
}

function unwrapList(result) {
  if (Array.isArray(result)) return { rows: result, total: result.length };
  return result;
}

async function writeMeta(req, body) {
  const s = writeScope(req, body || {});
  if (s.error) return { ok: false, status: s.status || 400, error: s.error };
  const db = await getDb();
  const loc = await db.collection('locations').findOne({ id: Number(s.locationId) });
  if (!loc) return { ok: false, status: 400, error: 'Jagah nahi mili' };
  if (loc.status === 'inactive' && req.user.role !== 'admin') {
    return { ok: false, status: 403, error: 'Ye jagah deactivate hai' };
  }
  const locationName = loc.name || (await locationNameOf(db, s.locationId));
  return {
    ok: true,
    meta: {
      locationId: s.locationId,
      locationName,
      email: req.user.email,
      role: req.user.role,
      name: req.user.name || '',
      userId: req.user.id || null,
    },
  };
}

app.get('/api/ready', (_req, res) => {
  res.json({ ok: true, service: 'bsnl-sim-api', version: 'locations-8' });
});

app.get('/api/health', async (_req, res) => {
  try {
    await getDb();
    res.json({ ok: true, message: 'BSNL SIM API connected (MongoDB)' });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/login', async (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const locked = loginGuard(req, email);
    if (!locked.ok) return res.status(429).json({ ok: false, error: locked.error });
    const out = await login(await getDb(), req.body, req);
    if (out.status === 200) loginClear(req, email);
    send(res, out);
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/forgot-password', async (req, res) => {
  try {
    send(res, await forgotPassword(await getDb(), req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/me', requireUser, async (req, res) => {
  try {
    send(res, await updateMe(await getDb(), req.user, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/me/password', requireUser, async (req, res) => {
  try {
    send(res, await changePassword(await getDb(), req.user, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/locations/preview', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await previewLocation(await getDb(), req.query?.name || req.query?.q || ''));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/recycle', requireUser, async (req, res) => {
  try {
    send(res, await listDeleted(await getDb(), req.user, req.query));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/recycle/:type/:id/restore', requireUser, async (req, res) => {
  try {
    send(res, await restoreRow(await getDb(), req.user, req.params.type, req.params.id));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/recycle/:type/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await purgeRow(await getDb(), req.user, req.params.type, req.params.id));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/search', requireUser, async (req, res) => {
  try {
    send(res, await globalSearch(await getDb(), req.user, req.query?.q || req.query?.search || ''));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/notifications', requireUser, async (req, res) => {
  try {
    send(res, await listNotifications(await getDb(), req.user));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/system', requireUser, requireAdmin, async (_req, res) => {
  try {
    send(res, await systemHealth(await getDb()));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/logout', requireUser, async (req, res) => {
  try {
    const { logActivity } = require('./lib/activity');
    await logActivity(await getDb(), {
      email: req.user.email,
      role: req.user.role,
      name: req.user.name,
      action: 'logout',
      section: 'auth',
      locationId: req.user.locationId,
      locationName: req.user.locationName,
      detail: `${req.user.name || req.user.email} logged out`,
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/stock', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, { locationId: req.query.locationId });
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await getStock(await getDb(), w.meta.locationId));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/stock', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, req.body);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await saveStock(await getDb(), req.user, w.meta.locationId, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/closing', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, { locationId: req.query.locationId });
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await listClosing(await getDb(), w.meta.locationId, req.query));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/closing', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, req.body);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await addClosing(await getDb(), req.user, w.meta.locationId, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/closing/:id/review', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await reviewClosing(await getDb(), req.user, req.params.id, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/today', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, { locationId: req.query.locationId });
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    const stats = await todayStats(await getDb(), w.meta.locationId);
    res.json({ ok: true, ...stats });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/import/:kind', requireUser, async (req, res) => {
  try {
    const kind = String(req.params.kind || '').toLowerCase();
    if (!['sims', 'cbc', 'ctopup'].includes(kind)) {
      return res.status(400).json({ ok: false, error: 'Invalid import type' });
    }
    const w = await writeMeta(req, req.body);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await importRows(await getDb(), w.meta, kind, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/me', requireUser, async (req, res) => {
  try {
    const db = await getDb();
    const user = await db.collection('users').findOne({ email: req.user.email });
    if (!user) return res.status(401).json({ ok: false, error: 'Login karo' });
    if (user.status === 'inactive') return res.status(403).json({ ok: false, error: 'Account deactivate hai' });
    res.json({ ok: true, user: publicUser(user), token: signToken(user) });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/locations', requireUser, async (req, res) => {
  try {
    const rows = await listLocations(await getDb(), req.user);
    res.json({ ok: true, rows });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/locations', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await addLocation(await getDb(), req.user, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/locations/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await updateLocation(await getDb(), req.user, req.params.id, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/locations/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await deleteLocation(await getDb(), req.user, req.params.id));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/employees', requireUser, requireAdmin, async (req, res) => {
  try {
    const out = await listEmployees(await getDb(), req.query);
    res.json({ ok: true, ...out });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/employees/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await employeeDetail(await getDb(), req.user, req.params.id));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/employees', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await addEmployee(await getDb(), req.user, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/employees/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await updateEmployee(await getDb(), req.user, req.params.id, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/employees/:id/reset-password', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await resetPassword(await getDb(), req.user, req.params.id, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/employees/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await deleteEmployee(await getDb(), req.user, req.params.id));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/summary', requireUser, requireAdmin, async (_req, res) => {
  try {
    const summary = await adminSummary(await getDb());
    res.json({ ok: true, ...summary });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/summary/location/:id', requireUser, async (req, res) => {
  try {
    send(res, await locationSummary(await getDb(), req.user, req.params.id));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/reports', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await buildReport(await getDb(), req.user, req.query));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/activity', requireUser, async (req, res) => {
  try {
    const out = await listActivity(await getDb(), req.user, req.query);
    if (out.error) return res.status(out.status || 400).json({ ok: false, error: out.error });
    res.json({ ok: true, ...out });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/sims', requireUser, async (req, res) => {
  try {
    const s = scoped(req);
    if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
    const out = unwrapList(await listSims(await getDb(), s));
    send(res, { status: 200, json: { ok: true, ...out } });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/sims', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, req.body);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await addSim(await getDb(), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/sims/:id', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, req.body);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await updateSim(await getDb(), req.params.id, req.body, w.meta, (row) => assertRowLocation(req, row, w.meta.locationId)));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/sims/:id', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, { locationId: req.query.locationId });
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await deleteSim(await getDb(), req.params.id, w.meta, (row) => assertRowLocation(req, row, w.meta.locationId)));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

function mountCrud(prefix, api) {
  app.get(prefix, requireUser, async (req, res) => {
    try {
      const s = scoped(req);
      if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
      const out = unwrapList(await api.list(await getDb(), s));
      send(res, { status: 200, json: { ok: true, ...out } });
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.post(prefix, requireUser, async (req, res) => {
    try {
      const w = await writeMeta(req, req.body);
      if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
      send(res, await api.add(await getDb(), req.body, w.meta));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.put(`${prefix}/:id`, requireUser, async (req, res) => {
    try {
      const w = await writeMeta(req, req.body);
      if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
      send(res, await api.update(await getDb(), req.params.id, req.body, w.meta, (row) => assertRowLocation(req, row, w.meta.locationId)));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.delete(`${prefix}/:id`, requireUser, async (req, res) => {
    try {
      const w = await writeMeta(req, { locationId: req.query.locationId });
      if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
      send(res, await api.remove(await getDb(), req.params.id, w.meta, (row) => assertRowLocation(req, row, w.meta.locationId)));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
}

mountCrud('/api/cbc', cbc);
mountCrud('/api/ctopup', ctopup);

if (fs.existsSync(WEB_DIR)) {
  app.use(express.static(WEB_DIR));
  app.get(/^(?!\/api).*/, (_req, res) => {
    res.sendFile(path.join(WEB_DIR, 'index.html'));
  });
} else {
  app.get('/', (_req, res) => {
    res.json({
      ok: true,
      message: 'BSNL SIM API (MongoDB). Flutter UI: ../bsnl_sim_portal',
    });
  });
}

async function start() {
  try {
    const db = await getDb();
    await seedUsers(db);
    await ensureIndexes(db);
    console.log('Users, locations, indexes ready');
  } catch (e) {
    console.warn('Startup seed/index skip:', String(e.message || e));
  }
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`BSNL SIM API  http://localhost:${PORT}  (MongoDB)`);
    if (!process.env.MONGODB_URI) {
      console.warn('WARNING: MONGODB_URI set nahi hai. backend/.env dekho.');
    }
  });
}

start();
