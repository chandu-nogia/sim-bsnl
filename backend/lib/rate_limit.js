'use strict';

const hits = new Map();

function clientKey(req, extra = '') {
  const ip = String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'ip')
    .split(',')[0]
    .trim();
  return `${ip}|${extra}`;
}

function consume(key, { limit = 5, windowMs = 15 * 60 * 1000 } = {}) {
  const now = Date.now();
  const row = hits.get(key);
  if (!row || now > row.resetAt) {
    hits.set(key, { count: 1, resetAt: now + windowMs });
    return { ok: true, remaining: limit - 1 };
  }
  row.count += 1;
  if (row.count > limit) {
    const mins = Math.ceil((row.resetAt - now) / 60000);
    return { ok: false, error: `Bahut attempts. ${mins} minute baad try karo.` };
  }
  return { ok: true, remaining: limit - row.count };
}

function reset(key) {
  hits.delete(key);
}

function loginGuard(req, email) {
  return consume(clientKey(req, String(email || '').toLowerCase()), { limit: 5, windowMs: 15 * 60 * 1000 });
}

function loginClear(req, email) {
  reset(clientKey(req, String(email || '').toLowerCase()));
}

module.exports = { consume, reset, loginGuard, loginClear };
