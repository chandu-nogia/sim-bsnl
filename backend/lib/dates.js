'use strict';

function dateKeyOf(raw) {
  const t = String(raw || '').trim();
  if (!t) return '';
  const iso = t.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`;
  const p = t.split(/[/\-.]/);
  if (p.length !== 3) return '';
  let a = Number.parseInt(p[0], 10);
  let b = Number.parseInt(p[1], 10);
  let y = Number.parseInt(p[2], 10);
  if (!a || !b || !y) return '';
  if (y < 100) y += 2000;
  let year;
  let month;
  let day;
  if (String(p[0]).trim().length === 4) {
    year = a;
    month = b;
    day = Number.parseInt(p[2], 10);
    if (day < 100 && String(p[2]).trim().length <= 2) day = y;
  } else {
    day = a;
    month = b;
    year = y;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) return '';
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function applyAmountRange(q, min, max) {
  const { moneyNumber } = require('./password');
  const hasMin = String(min ?? '').trim() !== '';
  const hasMax = String(max ?? '').trim() !== '';
  if (!hasMin && !hasMax) return q;
  q.amountNum = {};
  if (hasMin) q.amountNum.$gte = moneyNumber(min);
  if (hasMax) q.amountNum.$lte = moneyNumber(max);
  return q;
}

function applyDateRange(q, from, to) {
  const f = dateKeyOf(from) || String(from || '').slice(0, 10);
  const t = dateKeyOf(to) || String(to || '').slice(0, 10);
  if (!f && !t) return q;
  const range = {};
  if (f && /^\d{4}-\d{2}-\d{2}$/.test(f)) range.$gte = f;
  if (t && /^\d{4}-\d{2}-\d{2}$/.test(t)) range.$lte = t;
  if (!Object.keys(range).length) return q;
  q.dateKey = range;
  return q;
}

function sortSpec(scope) {
  const dir = String(scope.order || 'desc').toLowerCase() === 'asc' ? 1 : -1;
  const key = String(scope.sort || 'date').toLowerCase();
  if (key === 'amount') return { amountNum: dir, id: dir };
  if (key === 'commission') return { commissionNum: dir, id: dir };
  if (key === 'balance') return { balanceNum: dir, id: dir };
  if (key === 'name') return { name: dir, id: dir };
  if (key === 'id') return { id: dir };
  return { dateKey: dir, id: dir };
}

async function backfillDateKeys(db) {
  for (const name of ['sims', 'cbc', 'ctopup', 'wallet_txns']) {
    const col = db.collection(name);
    const rows = await col.find({
      $or: [{ dateKey: { $exists: false } }, { dateKey: null }, { dateKey: '' }],
    }).project({ _id: 1, date: 1 }).limit(5000).toArray();
    for (const r of rows) {
      const key = dateKeyOf(r.date);
      if (key) await col.updateOne({ _id: r._id }, { $set: { dateKey: key } });
    }
  }
}

module.exports = { dateKeyOf, applyDateRange, applyAmountRange, sortSpec, backfillDateKeys };
