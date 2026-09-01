'use strict';

require('dotenv').config();

const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');

const { getDb } = require('./lib/db');
const { listSims, addSim, updateSim, deleteSim } = require('./lib/sims');
const { seedUsers, login, requireUser, requireAdmin } = require('./lib/auth');
const { cbc, ctopup } = require('./lib/records');

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

app.get('/api/me', requireUser, (req, res) => {
  res.json({ ok: true, user: req.user });
});

app.get('/api/sims', requireUser, async (_req, res) => {
  try {
    send(res, { status: 200, json: { ok: true, rows: await listSims(await getDb()) } });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/sims', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await addSim(await getDb(), req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/sims/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await updateSim(await getDb(), req.params.id, req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/sims/:id', requireUser, requireAdmin, async (req, res) => {
  try {
    send(res, await deleteSim(await getDb(), req.params.id));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

function mountCrud(prefix, api) {
  app.get(prefix, requireUser, async (_req, res) => {
    try {
      send(res, { status: 200, json: { ok: true, rows: await api.list(await getDb()) } });
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.post(prefix, requireUser, requireAdmin, async (req, res) => {
    try {
      send(res, await api.add(await getDb(), req.body));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.put(`${prefix}/:id`, requireUser, requireAdmin, async (req, res) => {
    try {
      send(res, await api.update(await getDb(), req.params.id, req.body));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.delete(`${prefix}/:id`, requireUser, requireAdmin, async (req, res) => {
    try {
      send(res, await api.remove(await getDb(), req.params.id));
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
    console.log('Users ready: admin + employee');
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
