'use strict';

const {
  computeUsage,
  calculateUsageCommission,
  validateUsage,
  resolveUsageCommission,
  configuredCommissionPaise,
  fromPaise,
} = require('./money');

function publicConfig() {
  return {
    commissionMode: 'balance-minus-amount-plus-commission',
    formula: 'newBalance = oldBalance - amount + commission',
    commissionPercent: 1,
    commissionNote: 'Commission 1% automatic. Remaining/Balance type karne se wallet nahi badhta.',
    ctopupTypes: ['Recharge', 'Activation', 'Replacement', 'Port', 'Other'],
  };
}

function applyCommissionFromBalances(row, previousPaise) {
  const { toPaise } = require('./money');
  const amount = toPaise(row.amount);
  if (!amount.ok || amount.paise <= 0) {
    row.commission = '0.00';
    row.commissionNum = 0;
    row.commissionPaise = 0;
    row.previousBalancePaise = previousPaise || 0;
    row.expectedBalancePaise = (previousPaise || 0) - (amount.ok ? amount.paise : 0);
    return row;
  }
  const resolved = resolveUsageCommission({
    amountPaise: amount.paise,
  });
  const calc = computeUsage({
    previousPaise: previousPaise || 0,
    amountPaise: amount.paise,
    commissionPaise: resolved.ok ? resolved.commissionPaise : 0,
  });
  row.amountPaise = calc.amountPaise;
  row.commission = calc.commission;
  row.commissionNum = calc.commissionPaise / 100;
  row.commissionPaise = calc.commissionPaise;
  row.previousBalance = calc.previous;
  row.previousBalancePaise = calc.previousPaise;
  row.expectedBalance = calc.expected;
  row.expectedBalancePaise = calc.expectedPaise;
  row.actualBalance = calc.newBalance;
  row.actualBalancePaise = calc.newBalancePaise;
  row.balance = calc.newBalance;
  row.balanceNum = calc.newBalancePaise / 100;
  row.balancePaise = calc.newBalancePaise;
  return row;
}

module.exports = {
  publicConfig,
  calculateUsageCommission,
  validateUsage,
  applyCommissionFromBalances,
  configuredCommissionPaise,
  fromPaise,
};
