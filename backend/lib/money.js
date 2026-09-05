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

/**
 * commission = actualBalance - (previousBalance - transactionAmount)
 * All values in paise (integers).
 */
function calculateUsageCommission({ previousPaise, amountPaise, actualPaise }) {
  const previous = Number(previousPaise) || 0;
  const amount = Number(amountPaise) || 0;
  const actual = Number(actualPaise) || 0;
  const expected = previous - amount;
  const commission = actual - expected;
  return {
    previousPaise: previous,
    amountPaise: amount,
    actualPaise: actual,
    expectedPaise: expected,
    commissionPaise: commission,
    previous: fromPaise(previous),
    amount: fromPaise(amount),
    actual: fromPaise(actual),
    expected: fromPaise(expected),
    commission: fromPaise(commission),
  };
}

function validateUsage({ previousPaise, amountPaise, actualPaise }) {
  const calc = calculateUsageCommission({ previousPaise, amountPaise, actualPaise });
  if (calc.amountPaise <= 0) return { ok: false, error: 'Transaction amount 0 se zyada hona chahiye', calc };
  if (calc.actualPaise < 0) return { ok: false, error: 'Actual balance negative nahi ho sakta', calc };
  if (calc.commissionPaise < 0) {
    return {
      ok: false,
      error: `Commission negative nahi ho sakti (expected ₹${calc.expected}, actual ₹${calc.actual})`,
      calc,
    };
  }
  return { ok: true, calc };
}

function normalizeService(raw) {
  const s = String(raw || '').trim().toLowerCase();
  if (s === 'cbc' || s === 'cbp') return 'CBP';
  if (s === 'ctopup' || s === 'c-topup' || s === 'topup') return 'CTOPUP';
  return '';
}

module.exports = {
  toPaise,
  requirePositivePaise,
  fromPaise,
  paiseOf,
  rupeeNum,
  calculateUsageCommission,
  validateUsage,
  normalizeService,
};
