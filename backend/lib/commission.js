'use strict';

const { calculateUsageCommission, validateUsage, fromPaise } = require('./money');

function publicConfig() {
  return {
    commissionMode: 'actual-minus-expected',
    formula: 'commission = actualBalance - (previousBalance - transactionAmount)',
    ctopupTypes: ['Recharge', 'Activation', 'Replacement', 'Port', 'Other'],
  };
}

function applyCommissionFromBalances(row, previousPaise) {
  const { toPaise } = require('./money');
  const amount = toPaise(row.amount);
  const actual = toPaise(row.actualBalance ?? row.balance);
  if (!amount.ok || amount.paise <= 0 || !actual.ok) {
    row.commission = '0.00';
    row.commissionNum = 0;
    row.commissionPaise = 0;
    row.previousBalancePaise = previousPaise || 0;
    row.expectedBalancePaise = (previousPaise || 0) - (amount.ok ? amount.paise : 0);
    return row;
  }
  const calc = calculateUsageCommission({
    previousPaise: previousPaise || 0,
    amountPaise: amount.paise,
    actualPaise: actual.paise,
  });
  row.amountPaise = calc.amountPaise;
  row.commission = calc.commission;
  row.commissionNum = calc.commissionPaise / 100;
  row.commissionPaise = calc.commissionPaise;
  row.previousBalance = calc.previous;
  row.previousBalancePaise = calc.previousPaise;
  row.expectedBalance = calc.expected;
  row.expectedBalancePaise = calc.expectedPaise;
  row.actualBalance = calc.actual;
  row.actualBalancePaise = calc.actualPaise;
  row.balance = calc.actual;
  row.balanceNum = calc.actualPaise / 100;
  row.balancePaise = calc.actualPaise;
  return row;
}

module.exports = {
  publicConfig,
  calculateUsageCommission,
  validateUsage,
  applyCommissionFromBalances,
  fromPaise,
};
