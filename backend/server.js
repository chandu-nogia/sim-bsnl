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
const { adminSummary } = require('./lib/summary');

const PORT = Number(process.env.PORT) || 5050;
const WEB_DIR = path.join(__dirname, '..', 'bsnl_sim_portal', 'build', 'web');

const app = express();
app.set('trust proxy', 1);
app.use(cors({
  origin: true,
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options('*', cors());
app.use(express.json({ limit: '1mb' }));

function send(res, out) {
  res.status(out.status).json(out.json);
}

function scoped(req) {
  const s = listScope(req);
  if (s.error) return { ok: false, status: s.status || 400, error: s.error };
  return { ok: true, ...s };
}

async function writeMeta(req, body) {
  const s = writeScope(req, body || {});
  if (s.error) return { ok: false, status: s.status || 400, error: s.error };
  const db = await getDb();
  const locationName = s.locationName || (await locationNameOf(db, s.locationId));
  return {
    ok: true,
    meta: {
      locationId: s.locationId,
      locationName,
      email: req.user.email,
      role: req.user.role,
    },
  };
}

app.get('/api/ready', (_req, res) => {
  res.json({ ok: true, service: 'bsnl-sim-api' });
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
    send(res, await login(await getDb(), req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/me', requireUser, async (req, res) => {
  try {
    const db = await getDb();
    const user = await db.collection('users').findOne({ email: req.user.email });
    if (!user) return res.status(401).json({ ok: false, error: 'Login karo' });
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

app.get('/api/summary', requireUser, requireAdmin, async (_req, res) => {
  try {
    const summary = await adminSummary(await getDb());
    res.json({ ok: true, ...summary });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/activity', requireUser, async (req, res) => {
  try {
    const rows = await listActivity(await getDb(), req.user, req.query.limit);
    res.json({ ok: true, rows });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/sims', requireUser, async (req, res) => {
  try {
    const s = scoped(req);
    if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
    send(res, { status: 200, json: { ok: true, rows: await listSims(await getDb(), s) } });
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
    send(res, await updateSim(await getDb(), req.params.id, req.body, w.meta, (row) => assertRowLocation(req, row)));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/sims/:id', requireUser, async (req, res) => {
  try {
    const w = await writeMeta(req, { locationId: req.query.locationId });
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await deleteSim(await getDb(), req.params.id, w.meta, (row) => assertRowLocation(req, row)));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

function mountCrud(prefix, api) {
  app.get(prefix, requireUser, async (req, res) => {
    try {
      const s = scoped(req);
      if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
      send(res, { status: 200, json: { ok: true, rows: await api.list(await getDb(), s) } });
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
      send(res, await api.update(await getDb(), req.params.id, req.body, w.meta, (row) => assertRowLocation(req, row)));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.delete(`${prefix}/:id`, requireUser, async (req, res) => {
    try {
      const w = await writeMeta(req, { locationId: req.query.locationId });
      if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
      send(res, await api.remove(await getDb(), req.params.id, w.meta, (row) => assertRowLocation(req, row)));
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
    console.log('Users ready: admin + location employees');
  } catch (e) {
    console.warn('User seed skip:', String(e.message || e));
  }
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`BSNL SIM API  http://localhost:${PORT}  (MongoDB)`);
    if (!process.env.MONGODB_URI) {
      console.warn('WARNING: MONGODB_URI set nahi hai. backend/.env dekho.');
    }
  });
}

start();
