'use strict';

const { getDb } = require('./db');
const { listSims, addSim, updateSim, deleteSim } = require('./sims');

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

async function handleApi(request, env) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }

  try {
    if (path === '/api/health' && request.method === 'GET') {
      await getDb(env);
      return json(200, { ok: true, message: 'BSNL SIM API connected (MongoDB)' });
    }

    const db = await getDb(env);

    if (path === '/api/sims' && request.method === 'GET') {
      const out = await listSims(db);
      const payload = Array.isArray(out) ? { rows: out } : out;
      return json(200, { ok: true, ...payload });
    }

    if (path === '/api/sims' && request.method === 'POST') {
      const body = await request.json().catch(() => ({}));
      const out = await addSim(db, body);
      return json(out.status, out.json);
    }

    const one = path.match(/^\/api\/sims\/(\d+)$/);
    if (one && request.method === 'PUT') {
      const body = await request.json().catch(() => ({}));
      const out = await updateSim(db, one[1], body);
      return json(out.status, out.json);
    }
    if (one && request.method === 'DELETE') {
      const out = await deleteSim(db, one[1]);
      return json(out.status, out.json);
    }

    return json(404, { ok: false, error: 'Unknown API route' });
  } catch (e) {
    return json(500, { ok: false, error: String(e.message || e) });
  }
}

module.exports = { handleApi, CORS };
