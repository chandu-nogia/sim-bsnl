'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryDb, meta } = require('./helpers');
const {
  addMoney,
  applyUsage,
  reverseUsage,
  ensureWallet,
  snapshotBoth,
} = require('../lib/service_wallet');
const { cbc, ctopup } = require('../lib/records');

function dbReady() {
  const db = createMemoryDb();
  db.seedKhatu();
  return db;
}

test('Test 4: multiple wallet credits accumulate', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '10000' }, m);
  await addMoney(db, 'CBP', { amount: '5000' }, m);
  const third = await addMoney(db, 'CBP', { amount: '10000' }, m);
  assert.equal(third.status, 200, third.json && third.json.error);
  assert.ok(third.json.wallet, 'wallet missing from add-money response');
  assert.equal(Number(third.json.wallet.currentBalancePaise), 2500000);
  assert.equal(Number(third.json.wallet.totalCreditsPaise), 2500000);
  assert.equal(db._store.wallet_ledger.filter((r) => r.transactionType === 'CREDIT').length, 3);
});

test('Test 5: multiple transactions accumulate commission', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const a = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '24800', transactionId: 'TX1' }, m);
  const b = await applyUsage(db, 'CBP', { amount: '500', actualBalance: '24450', transactionId: 'TX2' }, m);
  assert.equal(a.json.calc.commissionPaise, 12500);
  assert.equal(b.json.calc.commissionPaise, 15000);
  assert.equal(b.json.wallet.currentBalancePaise, 2445000);
  assert.equal(b.json.wallet.totalCommissionPaise, 27500);
  assert.equal(b.json.wallet.totalTransactionAmountPaise, 92500);
});

test('Test 6: CBP and CTOPUP stay separate', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  await addMoney(db, 'CTOPUP', { amount: '10000' }, m);
  await applyUsage(db, 'CBP', { amount: '425', actualBalance: '24800', transactionId: 'CBP1' }, m);
  await applyUsage(db, 'CTOPUP', { amount: '200', actualBalance: '9850', transactionId: 'TOP1' }, m);
  const snap = await snapshotBoth(db);
  assert.equal(snap.cbp.currentBalancePaise, 2480000);
  assert.equal(snap.cbp.totalCommissionPaise, 12500);
  assert.equal(snap.ctopup.currentBalancePaise, 985000);
  assert.equal(snap.ctopup.totalCommissionPaise, 5000);
  assert.notEqual(snap.cbp.currentBalancePaise, snap.ctopup.currentBalancePaise);
});

test('Test 7: duplicate reference does not create duplicate commission', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const first = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '24800', transactionId: 'TX001' }, m);
  const dup = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '24800', transactionId: 'TX001' }, m);
  assert.equal(first.status, 200);
  assert.equal(dup.status, 409);
  const wallet = await ensureWallet(db, 'CBP');
  assert.equal(wallet.totalCommissionPaise, 12500);
  assert.equal(wallet.currentBalancePaise, 2480000);
});

test('Test 8: failed transaction does not change wallet', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CTOPUP', { amount: '5000' }, m);
  const before = await ensureWallet(db, 'CTOPUP');
  const out = await ctopup.add(db, {
    amount: '425',
    actualBalance: '4600',
    status: 'Failed',
    transactionId: 'FAIL1',
    number: '9999999999',
  }, m);
  assert.equal(out.status, 200);
  const after = await ensureWallet(db, 'CTOPUP');
  assert.equal(after.currentBalancePaise, before.currentBalancePaise);
  assert.equal(after.totalCommissionPaise, 0);
  assert.equal(out.json.row.transactionStatus, 'FAILED');
});

test('Test 9: reversal restores accounting', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const added = await cbc.add(db, {
    amount: '425',
    actualBalance: '24800',
    transactionId: 'REV1',
    mobile: '8888888888',
  }, m);
  assert.equal(added.status, 200);
  assert.equal(added.json.row.commission, '125.00');
  const rev = await reverseUsage(db, 'CBP', { ...added.json.row, amountPaise: 42500, commissionPaise: 12500, walletApplied: true }, m);
  assert.equal(rev.status, 200);
  const wallet = await ensureWallet(db, 'CBP');
  assert.equal(wallet.currentBalancePaise, 2510000);
  assert.equal(wallet.totalCommissionPaise, 0);
  assert.equal(wallet.totalTransactionAmountPaise, 0);
});

test('Test 10: concurrent transactions do not corrupt wallet', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const [a, b] = await Promise.all([
    applyUsage(db, 'CBP', { amount: '425', actualBalance: '24800', transactionId: 'C1' }, m),
    applyUsage(db, 'CBP', { amount: '500', actualBalance: '24600', transactionId: 'C2' }, m),
  ]);
  const statuses = [a.status, b.status].sort();
  assert.ok(statuses.includes(200));
  assert.ok(statuses.includes(409) || statuses.every((s) => s === 200));
  const wallet = await ensureWallet(db, 'CBP');
  const usage = (db._store.wallet_ledger || []).filter((r) => r.transactionType === 'USAGE');
  if (statuses.includes(409)) {
    assert.equal(usage.length, 1);
    assert.ok(wallet.currentBalancePaise === 2480000 || wallet.currentBalancePaise === 2460000);
  } else {
    assert.equal(usage.length, 2);
  }
  assert.ok(wallet.currentBalancePaise >= 0);
});

test('empty remaining balance means no extra commission', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const out = await applyUsage(db, 'CBP', { amount: '425', transactionId: 'NO-BAL' }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.calc.commissionPaise, 0);
  assert.equal(out.json.wallet.currentBalancePaise, 2467500);
});

test('zero commission usage', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const out = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '24675', transactionId: 'Z0' }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.calc.commissionPaise, 0);
  assert.equal(out.json.wallet.currentBalancePaise, 2467500);
});

test('record add uses backend commission not frontend value', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const out = await cbc.add(db, {
    amount: '425',
    actualBalance: '24800',
    commission: '425',
    transactionId: 'NO-TRUST',
  }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.row.commission, '125.00');
  assert.notEqual(out.json.row.commission, '425.00');
  assert.equal(out.json.row.amount, '425.00');
});
