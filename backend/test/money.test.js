'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  calculateUsageCommission,
  computeUsage,
  validateUsage,
  resolveUsageCommission,
  configuredCommissionPaise,
  toPaise,
  fromPaise,
} = require('../lib/money');

test('formula: newBalance = oldBalance - amount + commission', () => {
  const calc = computeUsage({
    previousPaise: 100000,
    amountPaise: 42500,
    commissionPaise: 1000,
  });
  assert.equal(calc.newBalancePaise, 58500);
  assert.equal(calc.netImpactPaise, -41500);
  assert.equal(calc.newBalance, '585.00');
  assert.equal(calc.formula, 'newBalance = oldBalance - amount + commission');
});

test('Test 1: zero commission', () => {
  const calc = calculateUsageCommission({
    previousPaise: 2510000,
    amountPaise: 42500,
    actualPaise: 2467500,
  });
  assert.equal(calc.expectedPaise, 2467500);
  assert.equal(calc.commissionPaise, 0);
  assert.equal(calc.newBalancePaise, 2467500);
  assert.equal(calc.amount, '425.00');
  assert.equal(calc.commission, '0.00');
});

test('Test 2: commission 125', () => {
  const calc = calculateUsageCommission({
    previousPaise: 2510000,
    amountPaise: 42500,
    actualPaise: 2480000,
  });
  assert.equal(calc.expectedPaise, 2467500);
  assert.equal(calc.commissionPaise, 12500);
  assert.equal(calc.amount, '425.00');
  assert.equal(calc.commission, '125.00');
  assert.equal(calc.actual, '24800.00');
  assert.equal(calc.newBalancePaise, 2480000);
});

test('Test 3: second transaction commission 150', () => {
  const calc = calculateUsageCommission({
    previousPaise: 2480000,
    amountPaise: 50000,
    actualPaise: 2445000,
  });
  assert.equal(calc.expectedPaise, 2430000);
  assert.equal(calc.commissionPaise, 15000);
  assert.equal(calc.commission, '150.00');
});

test('empty remaining uses configured 1% commission', () => {
  const resolved = resolveUsageCommission({
    previousPaise: 100000,
    amountPaise: 42500,
    actualRaw: '',
  });
  assert.equal(resolved.ok, true);
  assert.equal(resolved.commissionPaise, 425);
  assert.equal(configuredCommissionPaise(42500), 425);
});

test('typed remaining cannot change commission', () => {
  const resolved = resolveUsageCommission({
    previousPaise: 2000000,
    amountPaise: 42500,
    actualRaw: '25100',
  });
  assert.equal(resolved.commissionPaise, 425);
});

test('usage cannot increase wallet', () => {
  const checked = validateUsage({
    previousPaise: 2000000,
    amountPaise: 42500,
    commissionPaise: 60000,
  });
  assert.equal(checked.ok, false);
});

test('insufficient balance is rejected', () => {
  const checked = validateUsage({
    previousPaise: 30000,
    amountPaise: 42500,
    commissionPaise: 1000,
  });
  assert.equal(checked.ok, false);
  assert.equal(checked.code, 'INSUFFICIENT_BALANCE');
});

test('paise rounding stays exact', () => {
  assert.equal(toPaise('125.50').paise, 12550);
  assert.equal(fromPaise(12550), '125.50');
  assert.equal(validateUsage({ previousPaise: 100, amountPaise: 40, actualPaise: 50 }).ok, false);
});
