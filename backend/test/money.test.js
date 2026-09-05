'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { calculateUsageCommission, validateUsage, toPaise, fromPaise } = require('../lib/money');

test('Test 1: zero commission', () => {
  const calc = calculateUsageCommission({
    previousPaise: 2510000,
    amountPaise: 42500,
    actualPaise: 2467500,
  });
  assert.equal(calc.expectedPaise, 2467500);
  assert.equal(calc.commissionPaise, 0);
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

test('paise rounding stays exact', () => {
  assert.equal(toPaise('125.50').paise, 12550);
  assert.equal(fromPaise(12550), '125.50');
  assert.equal(validateUsage({ previousPaise: 100, amountPaise: 40, actualPaise: 50 }).ok, false);
});
