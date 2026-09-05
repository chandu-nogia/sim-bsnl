'use strict';

const { moneyNumber, moneyText } = require('./password');

function rateOf(envName, fallback) {
  const n = Number(process.env[envName]);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

function commissionConfig() {
  return {
    cbpPercent: rateOf('CBP_COMMISSION_PERCENT', 1),
    ctopupPercent: rateOf('CTOPUP_COMMISSION_PERCENT', 2),
    ctopupTypes: ['Recharge', 'Activation', 'Replacement', 'Port', 'Other'],
  };
}

function calcCommission(amount, percent) {
  const value = moneyNumber((moneyNumber(amount) * moneyNumber(percent)) / 100);
  return {
    value,
    text: moneyText(value),
    rate: moneyNumber(percent),
  };
}

function calculateCBPCommission(amount) {
  return calcCommission(amount, commissionConfig().cbpPercent);
}

function calculateCTOPUPCommission(amount) {
  return calcCommission(amount, commissionConfig().ctopupPercent);
}

function applyCommission(section, row) {
  const out = section === 'ctopup' ? calculateCTOPUPCommission(row.amount) : calculateCBPCommission(row.amount);
  row.commission = out.text;
  row.commissionNum = out.value;
  row.commissionRate = out.rate;
  return row;
}

function publicConfig() {
  const c = commissionConfig();
  return {
    cbpCommissionPercent: c.cbpPercent,
    ctopupCommissionPercent: c.ctopupPercent,
    ctopupTypes: c.ctopupTypes,
  };
}

module.exports = {
  commissionConfig,
  calculateCBPCommission,
  calculateCTOPUPCommission,
  applyCommission,
  publicConfig,
};
