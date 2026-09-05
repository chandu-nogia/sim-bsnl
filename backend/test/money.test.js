'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  calculateUsageCommission,
  computeUsage,
  validateUsage,
  resolveUsageCommission,
  configuredCommissionPaise,
  commissionFromRateBps,
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

test('statement Test 1: 24930.25 - 315 + 3.15 = 24618.40', () => {
  assert.equal(commissionFromRateBps(31500, 100), 315);
  const calc = computeUsage({ previousPaise: 2493025, amountPaise: 31500, commissionPaise: 315 });
  assert.equal(calc.commission, '3.15');
  assert.equal(calc.newBalancePaise, 2461840);
  assert.equal(calc.newBalance, '24618.40');
});

test('statement Test 2: 24618.40 - 590 + 5.90 = 24034.30', () => {
  assert.equal(commissionFromRateBps(59000, 100), 590);
  const calc = computeUsage({ previousPaise: 2461840, amountPaise: 59000, commissionPaise: 590 });
  assert.equal(calc.commission, '5.90');
  assert.equal(calc.newBalancePaise, 2403430);
  assert.equal(calc.newBalance, '24034.30');
});

test('statement Test 3: 24034.30 - 975 + 9.75 = 23069.05', () => {
  assert.equal(commissionFromRateBps(97500, 100), 975);
  const calc = computeUsage({ previousPaise: 2403430, amountPaise: 97500, commissionPaise: 975 });
  assert.equal(calc.commission, '9.75');
  assert.equal(calc.newBalancePaise, 2306905);
  assert.equal(calc.newBalance, '23069.05');
});

test('statement Test 5: net 594 > 500 rejects', () => {
  const comm = commissionFromRateBps(60000, 100);
  assert.equal(comm, 600);
  const checked = validateUsage({ previousPaise: 50000, amountPaise: 60000, commissionPaise: comm });
  assert.equal(checked.ok, false);
  assert.equal(checked.code, 'INSUFFICIENT_BALANCE');
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
