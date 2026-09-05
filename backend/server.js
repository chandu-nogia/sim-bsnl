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
  publicUser,
  signToken,
  listScope,
  writeScope,
  assertRowLocation,
} = require('./lib/auth');
const { cbc, ctopup } = require('./lib/records');
const { ownerDashboard } = require('./lib/summary');
const {
  setWallet,
  getWallet,
  listTransactions,
  addTransaction,
  updateTransaction,
  removeTransaction,
  ensureOpeningCredit,
} = require('./lib/wallet');
const {
  getService,
  listLedger,
  listCommission,
  listServiceTransactions,
  addMoney,
  withdraw,
  applyUsage,
  previewUsage,
  reverseByRef,
  snapshotBoth,
  migrateLegacy,
  rebuildCbpFromOpening,
  ensureWallet,
} = require('./lib/service_wallet');
const { publicConfig } = require('./lib/commission');
const { ensureIndexes } = require('./lib/indexes');
const { loginGuard, loginClear } = require('./lib/rate_limit');
const { changePassword, updateMe } = require('./lib/account');
const { globalSearch } = require('./lib/search');

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
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Location-Id', 'Accept'],
}));
app.options('*', cors({
  origin: corsOrigin,
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Location-Id', 'Accept'],
}));
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
    sort: req.query?.sort || 'date',
    order: req.query?.order || 'desc',
    status: req.query?.status || '',
    type: req.query?.type || '',
    txnType: req.query?.txnType || req.query?.transactionType || '',
    minAmount: req.query?.minAmount || req.query?.min || '',
    maxAmount: req.query?.maxAmount || req.query?.max || '',
    page: req.query?.page,
    limit: req.query?.limit,
  };
}

function unwrapList(result) {
  if (Array.isArray(result)) return { rows: result, total: result.length };
  return result;
}

function writeMeta(req) {
  const s = writeScope(req);
  if (s.error) return { ok: false, status: s.status || 400, error: s.error };
  return {
    ok: true,
    meta: {
      locationId: s.locationId,
      locationName: req.user.locationName || 'Khatushyamji',
      email: req.user.email,
      role: 'owner',
      name: req.user.name || '',
      userId: req.user.id || null,
      ip: String(req.headers['x-forwarded-for'] || req.ip || '').split(',')[0].trim(),
    },
  };
}

app.get('/api/ready', (_req, res) => {
  res.json({ ok: true, service: 'bsnl-sim-api', version: 'khatu-11' });
});

app.get('/api/health', async (_req, res) => {
  try {
    await getDb();
    res.json({ ok: true, message: 'BSNL Khatushyamji API connected' });
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

app.get('/api/search', requireUser, async (req, res) => {
  try {
    send(res, await globalSearch(await getDb(), req.user, req.query?.q || req.query?.search || ''));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/logout', requireUser, async (req, res) => {
  try {
    const { logActivity } = require('./lib/activity');
    await logActivity(await getDb(), {
      email: req.user.email,
      role: 'owner',
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

app.get('/api/me', requireUser, async (req, res) => {
  try {
    const db = await getDb();
    const user = await db.collection('users').findOne({ email: req.user.email });
    if (!user) return res.status(401).json({ ok: false, error: 'Login karo' });
    res.json({ ok: true, user: publicUser(user), token: signToken({ ...user, ...req.user }) });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/dashboard', requireUser, async (req, res) => {
  try {
    const data = await ownerDashboard(await getDb(), {
      from: req.query?.from || '',
      to: req.query?.to || '',
      period: req.query?.period || '',
    });
    res.json({ ok: true, ...data });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/wallet', requireUser, async (_req, res) => {
  try {
    send(res, await getWallet(await getDb()));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/wallet', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await setWallet(await getDb(), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/config', requireUser, async (_req, res) => {
  res.json({ ok: true, ...publicConfig() });
});

app.get('/api/wallet/summary', requireUser, async (_req, res) => {
  try {
    send(res, await getWallet(await getDb()));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/wallet/transactions', requireUser, async (req, res) => {
  try {
    const s = scoped(req);
    if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
    send(res, await listTransactions(await getDb(), s));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/wallet/transactions', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await addTransaction(await getDb(), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/wallet/transactions/:id', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await updateTransaction(await getDb(), req.params.id, req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/wallet/transactions/:id', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await removeTransaction(await getDb(), req.params.id, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

function serviceParam(req) {
  return req.params.service || req.params.serviceType || '';
}

app.get('/api/wallet/:service/balance', requireUser, async (req, res) => {
  try {
    send(res, await getService(await getDb(), serviceParam(req)));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/wallet/:service/ledger', requireUser, async (req, res) => {
  try {
    const s = scoped(req);
    if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
    send(res, await listLedger(await getDb(), serviceParam(req), s));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/wallet/:service/transactions', requireUser, async (req, res) => {
  try {
    const s = scoped(req);
    if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
    send(res, await listServiceTransactions(await getDb(), serviceParam(req), s));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/wallet/:service/commission', requireUser, async (req, res) => {
  try {
    const s = scoped(req);
    if (!s.ok) return res.status(s.status).json({ ok: false, error: s.error });
    send(res, await listCommission(await getDb(), serviceParam(req), s));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/wallet/:service/add-money', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await addMoney(await getDb(), serviceParam(req), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/wallet/:service/withdraw', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await withdraw(await getDb(), serviceParam(req), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/wallet/:service/preview', requireUser, async (req, res) => {
  try {
    send(res, await previewUsage(await getDb(), serviceParam(req), req.body));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/wallet/:service/transaction', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await applyUsage(await getDb(), serviceParam(req), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.post('/api/wallet/:service/reversal', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await reverseByRef(await getDb(), serviceParam(req), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.get('/api/wallet/:service', requireUser, async (req, res) => {
  try {
    const name = String(serviceParam(req) || '').toLowerCase();
    if (name === 'summary' || name === 'transactions') {
      return send(res, await getWallet(await getDb()));
    }
    send(res, await getService(await getDb(), serviceParam(req)));
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
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await addSim(await getDb(), req.body, w.meta));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.put('/api/sims/:id', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
    if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
    send(res, await updateSim(await getDb(), req.params.id, req.body, w.meta, (row) => assertRowLocation(req, row, w.meta.locationId)));
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});

app.delete('/api/sims/:id', requireUser, async (req, res) => {
  try {
    const w = writeMeta(req);
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
      const w = writeMeta(req);
      if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
      send(res, await api.add(await getDb(), req.body, w.meta));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.put(`${prefix}/:id`, requireUser, async (req, res) => {
    try {
      const w = writeMeta(req);
      if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
      send(res, await api.update(await getDb(), req.params.id, req.body, w.meta, (row) => assertRowLocation(req, row, w.meta.locationId)));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
  app.delete(`${prefix}/:id`, requireUser, async (req, res) => {
    try {
      const w = writeMeta(req);
      if (!w.ok) return res.status(w.status).json({ ok: false, error: w.error });
      send(res, await api.remove(await getDb(), req.params.id, w.meta, (row) => assertRowLocation(req, row, w.meta.locationId)));
    } catch (e) {
      res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });
}

mountCrud('/api/cbc', cbc);
mountCrud('/api/cbp', cbc);
mountCrud('/api/ctopup', ctopup);

if (fs.existsSync(WEB_DIR)) {
  app.use(express.static(WEB_DIR));
  app.get(/^(?!\/api).*/, (_req, res) => {
    res.sendFile(path.join(WEB_DIR, 'index.html'));
  });
} else {
  app.get('/', (_req, res) => {
    res.json({ ok: true, message: 'BSNL Khatushyamji API' });
  });
}

async function start() {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`BSNL Khatushyamji API  http://localhost:${PORT}`);
  });
  try {
    const db = await getDb();
    await seedUsers(db);
    const { backfillDateKeys } = require('./lib/dates');
    await backfillDateKeys(db);
    await ensureOpeningCredit(db);
    await ensureWallet(db, 'CBP');
    await ensureWallet(db, 'CTOPUP');
    await migrateLegacy(db);
    await rebuildCbpFromOpening(db);
    await snapshotBoth(db);
    await ensureIndexes(db);
    console.log('Owner account and Khatushyamji location ready');
  } catch (e) {
    console.warn('Startup seed/index skip:', String(e.message || e));
  }
}

start();
