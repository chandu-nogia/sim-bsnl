'use strict';

function validatePassword(raw, { required = true } = {}) {
  const password = String(raw ?? '');
  if (!password) {
    return required ? 'Password likho (kam se kam 8 character)' : null;
  }
  if (password.length < 8) return 'Password kam se kam 8 character ka ho';
  if (!/[0-9]/.test(password) && !/[^A-Za-z0-9]/.test(password)) {
    return 'Password mein number ya symbol bhi rakho';
  }
  return null;
}

function moneyNumber(v) {
  let s = String(v ?? '').trim().replace(/,/g, '');
  const neg = s.startsWith('-');
  s = s.replace(/[^0-9.]/g, '');
  if (!s || s === '.') return 0;
  const n = Number((neg ? '-' : '') + s);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : 0;
}

function moneyText(n) {
  return moneyNumber(n).toFixed(2);
}

function parseAmount(raw, { required = false, allowZero = true } = {}) {
  const s = String(raw ?? '').trim().replace(/,/g, '');
  if (!s) {
    if (required) return { ok: false, error: 'Amount likho' };
    return { ok: true, value: 0, text: '0.00' };
  }
  if (!/^-?\d+(\.\d+)?$/.test(s)) {
    return { ok: false, error: 'Amount number mein likho (jaise 12500.50)' };
  }
  const n = Number(s);
  if (!Number.isFinite(n)) return { ok: false, error: 'Amount galat hai' };
  if (n < 0) return { ok: false, error: 'Amount negative nahi ho sakta' };
  const value = Math.round(n * 100) / 100;
  if (!allowZero && value === 0) return { ok: false, error: 'Amount 0 nahi ho sakta' };
  return { ok: true, value, text: value.toFixed(2) };
}

module.exports = { validatePassword, moneyNumber, moneyText, parseAmount };
