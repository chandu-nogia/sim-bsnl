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
  const n = Number(String(v ?? '').replace(/[^0-9.]/g, ''));
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : 0;
}

module.exports = { validatePassword, moneyNumber };
