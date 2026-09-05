'use strict';

function toPaise(raw) {
  const s = String(raw ?? '').trim().replace(/,/g, '').replace(/₹/g, '');
  if (!s || s === '-' || s === '.') return { ok: false, error: 'Amount likho', paise: 0 };
  if (!/^-?\d+(\.\d+)?$/.test(s)) return { ok: false, error: 'Amount number mein likho (jaise 12500.50)', paise: 0 };
  const n = Number(s);
  if (!Number.isFinite(n)) return { ok: false, error: 'Amount galat hai', paise: 0 };
  const paise = Math.round(n * 100);
  return { ok: true, paise, text: fromPaise(paise) };
}

function requirePositivePaise(raw, label = 'Amount') {
  const parsed = toPaise(raw);
  if (!parsed.ok) return parsed;
  if (parsed.paise <= 0) return { ok: false, error: `${label} 0 se zyada hona chahiye`, paise: 0 };
  return parsed;
}

function fromPaise(paise) {
  const n = Number(paise) || 0;
  const sign = n < 0 ? '-' : '';
  const abs = Math.abs(n);
  const rupees = Math.floor(abs / 100);
  const p = String(abs % 100).padStart(2, '0');
  return `${sign}${rupees}.${p}`;
}

function paiseOf(raw) {
  if (typeof raw === 'number' && Number.isInteger(raw)) return raw;
  const parsed = toPaise(raw);
  return parsed.ok ? parsed.paise : 0;
}

function rupeeNum(paise) {
  return (Number(paise) || 0) / 100;
}

/** Backend-only automatic commission: 1% of amount, rounded to paise. */
function configuredCommissionPaise(amountPaise) {
  return Math.round((Number(amountPaise) || 0) / 100);
}

/**
 * Authoritative wallet formula (integer paise):
 * newBalance = oldBalance - amount + commission
 */
function computeUsage({ previousPaise, amountPaise, commissionPaise }) {
  const previous = Number(previousPaise) || 0;
  const amount = Number(amountPaise) || 0;
  const commission = Number(commissionPaise) || 0;
  const expected = previous - amount;
  const newBalance = previous - amount + commission;
  const netImpact = -amount + commission;
  return {
    previousPaise: previous,
    amountPaise: amount,
    commissionPaise: commission,
    expectedPaise: expected,
    newBalancePaise: newBalance,
    actualPaise: newBalance,
    netImpactPaise: netImpact,
    previous: fromPaise(previous),
    amount: fromPaise(amount),
    commission: fromPaise(commission),
    expected: fromPaise(expected),
    newBalance: fromPaise(newBalance),
    actual: fromPaise(newBalance),
    netImpact: fromPaise(netImpact),
    formula: 'newBalance = oldBalance - amount + commission',
  };
}

/**
 * Derive commission from a remaining/actual balance, or fall back to configured rate.
 * Never uses a client-supplied commission value.
 */
function resolveUsageCommission({ previousPaise, amountPaise, actualRaw }) {
  const previous = Number(previousPaise) || 0;
  const amount = Number(amountPaise) || 0;
  const raw = actualRaw === undefined || actualRaw === null ? '' : String(actualRaw).trim();
  if (raw === '') {
    return { ok: true, commissionPaise: configuredCommissionPaise(amount), source: 'configured' };
  }
  const actual = toPaise(raw);
  if (!actual.ok) {
    return { ok: false, error: 'Balance (jo khate mein bacha) number mein likho', commissionPaise: 0 };
  }
  return {
    ok: true,
    commissionPaise: actual.paise - (previous - amount),
    source: 'actual-remaining',
  };
}

function validateUsage({ previousPaise, amountPaise, actualPaise, commissionPaise }) {
  let commission = commissionPaise;
  if (commission == null && actualPaise != null) {
    commission = (Number(actualPaise) || 0) - ((Number(previousPaise) || 0) - (Number(amountPaise) || 0));
  }
  const calc = computeUsage({
    previousPaise,
    amountPaise,
    commissionPaise: Number(commission) || 0,
  });
  if (calc.amountPaise <= 0) {
    return { ok: false, error: 'Transaction amount 0 se zyada hona chahiye', calc };
  }
  if (calc.commissionPaise < 0) {
    return {
      ok: false,
      error: `Commission negative nahi ho sakti (expected ₹${calc.expected}, new ₹${calc.newBalance})`,
      calc,
    };
  }
  if (calc.previousPaise < calc.amountPaise) {
    return {
      ok: false,
      code: 'INSUFFICIENT_BALANCE',
      error: `Insufficient wallet balance (available ₹${calc.previous}, amount ₹${calc.amount})`,
      calc,
    };
  }
  if (calc.newBalancePaise < 0) {
    return { ok: false, error: 'Wallet balance invalid ho jayegi', calc };
  }
  return { ok: true, calc };
}

/** @deprecated prefer computeUsage; kept for existing callers */
function calculateUsageCommission({ previousPaise, amountPaise, actualPaise }) {
  const previous = Number(previousPaise) || 0;
  const amount = Number(amountPaise) || 0;
  const actual = Number(actualPaise) || 0;
  return computeUsage({
    previousPaise: previous,
    amountPaise: amount,
    commissionPaise: actual - (previous - amount),
  });
}

function normalizeService(raw) {
  const s = String(raw || '').trim().toLowerCase();
  if (s === 'cbc' || s === 'cbp') return 'CBP';
  if (s === 'ctopup' || s === 'c-topup' || s === 'topup') return 'CTOPUP';
  return '';
}

function usageApiFields(calc, { service, referenceId } = {}) {
  return {
    success: true,
    amount: rupeeNum(calc.amountPaise),
    commission: rupeeNum(calc.commissionPaise),
    previousBalance: rupeeNum(calc.previousPaise),
    newBalance: rupeeNum(calc.newBalancePaise),
    netImpact: rupeeNum(calc.netImpactPaise),
    referenceId: referenceId || '',
    service: service || '',
    formula: calc.formula,
  };
}

module.exports = {
  toPaise,
  requirePositivePaise,
  fromPaise,
  paiseOf,
  rupeeNum,
  configuredCommissionPaise,
  computeUsage,
  resolveUsageCommission,
  calculateUsageCommission,
  validateUsage,
  normalizeService,
  usageApiFields,
};
