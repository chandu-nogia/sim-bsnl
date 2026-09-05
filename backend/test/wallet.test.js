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

test('statement chain ends at 23069.05', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '24930.25' }, m);
  const a = await applyUsage(db, 'CBP', { amount: '315', transactionId: 'ST-2' }, m);
  assert.equal(a.status, 200, a.json && a.json.error);
  assert.equal(a.json.commission, 3.15);
  assert.equal(a.json.newBalance, 24618.4);
  const b = await applyUsage(db, 'CBP', { amount: '590', transactionId: 'ST-3' }, m);
  assert.equal(b.json.commission, 5.9);
  assert.equal(b.json.newBalance, 24034.3);
  const c = await applyUsage(db, 'CBP', { amount: '975', transactionId: 'ST-4' }, m);
  assert.equal(c.json.commission, 9.75);
  assert.equal(c.json.newBalance, 23069.05);
  assert.equal(c.json.wallet.currentBalancePaise, 2306905);
});

test('add money 25000 + 5000 = 30000', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25000' }, m);
  const out = await addMoney(db, 'CBP', { amount: '5000', paymentMethod: 'UPI', referenceId: 'UTR1' }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.wallet.currentBalancePaise, 3000000);
});

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
  assert.equal(a.json.calc.commissionPaise, 425);
  assert.equal(b.json.calc.commissionPaise, 500);
  assert.equal(b.json.wallet.currentBalancePaise, 2510000 - 42500 + 425 - 50000 + 500);
  assert.equal(b.json.wallet.totalCommissionPaise, 925);
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
  assert.equal(snap.cbp.currentBalancePaise, 2510000 - 42500 + 425);
  assert.equal(snap.cbp.totalCommissionPaise, 425);
  assert.equal(snap.ctopup.currentBalancePaise, 1000000 - 20000 + 200);
  assert.equal(snap.ctopup.totalCommissionPaise, 200);
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
  assert.equal(wallet.totalCommissionPaise, 425);
  assert.equal(wallet.currentBalancePaise, 2510000 - 42500 + 425);
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
  assert.equal(added.json.row.commission, '4.25');
  const rev = await reverseUsage(db, 'CBP', { ...added.json.row, amountPaise: 42500, commissionPaise: 425, walletApplied: true }, m);
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
    assert.ok(wallet.currentBalancePaise === 2467925 || wallet.currentBalancePaise === 2460500);
  } else {
    assert.equal(usage.length, 2);
  }
  assert.ok(wallet.currentBalancePaise >= 0);
});

test('empty remaining uses automatic 1% commission', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const out = await applyUsage(db, 'CBP', { amount: '425', transactionId: 'NO-BAL' }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.calc.commissionPaise, 425);
  assert.equal(out.json.wallet.currentBalancePaise, 2510000 - 42500 + 425);
  assert.equal(out.json.newBalance, 24679.25);
});

test('acceptance: 1000 - 425 + 1% then -200 + 1% then +500', async () => {
  const db = dbReady();
  const m = meta();
  const d1 = await addMoney(db, 'CBP', { amount: '1000' }, m);
  assert.equal(d1.json.wallet.currentBalancePaise, 100000);
  const cbp = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '25100', transactionId: 'ACC-CBP' }, m);
  assert.equal(cbp.status, 200, cbp.json && cbp.json.error);
  assert.equal(cbp.json.success, true);
  assert.equal(cbp.json.amount, 425);
  assert.equal(cbp.json.commission, 4.25);
  assert.equal(cbp.json.previousBalance, 1000);
  assert.equal(cbp.json.newBalance, 579.25);
  assert.equal(cbp.json.service, 'CBP');
  const top = await applyUsage(db, 'CBP', { amount: '200', actualBalance: '25100', transactionId: 'ACC-TOP' }, m);
  assert.equal(top.status, 200, top.json && top.json.error);
  assert.equal(top.json.newBalance, 381.25);
  assert.equal(top.json.commission, 2);
  const more = await addMoney(db, 'CBP', { amount: '500' }, m);
  assert.equal(more.json.wallet.currentBalancePaise, 88125);
});

test('acceptance: CTOPUP 585 - 200 + 1%', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CTOPUP', { amount: '585' }, m);
  const out = await applyUsage(db, 'CTOPUP', { amount: '200', actualBalance: '390', transactionId: 'T3' }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.newBalance, 387);
  assert.equal(out.json.commission, 2);
  assert.equal(out.json.service, 'CTOPUP');
});

test('acceptance: CBP 1000 - 425 + 1% = 579.25', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '1000' }, m);
  const out = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '585', transactionId: 'T2' }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.newBalance, 579.25);
  assert.equal(out.json.commission, 4.25);
  assert.equal(out.json.wallet.currentBalancePaise, 57925);
});

test('typed opening remaining does not credit CBP wallet', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '20000' }, m);
  const out = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '25100', transactionId: 'NO-INFLATE' }, m);
  assert.equal(out.status, 200, out.json && out.json.error);
  assert.ok(out.json.wallet.currentBalancePaise < 2000000);
  assert.equal(out.json.wallet.currentBalancePaise, 2000000 - 42500 + 425);
  assert.equal(out.json.commission, 4.25);
});

test('acceptance: insufficient balance rejects and wallet stays 300', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '300' }, m);
  const out = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '0', transactionId: 'LOW' }, m);
  assert.equal(out.status, 400);
  assert.match(String(out.json.error), /Insufficient/i);
  const wallet = await ensureWallet(db, 'CBP');
  assert.equal(wallet.currentBalancePaise, 30000);
  assert.equal(wallet.totalCommissionPaise, 0);
});

test('acceptance: duplicate reference does not change wallet', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '1000' }, m);
  const first = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '585', transactionId: 'DUP-REF' }, m);
  const second = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '585', transactionId: 'DUP-REF' }, m);
  assert.equal(first.status, 200);
  assert.equal(second.status, 409);
  assert.equal(second.json.duplicate, true);
  const wallet = await ensureWallet(db, 'CBP');
  assert.equal(wallet.currentBalancePaise, 57925);
  assert.equal(wallet.totalCommissionPaise, 425);
});

test('typed leftover remaining is ignored, 1% still applies', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '25100' }, m);
  const out = await applyUsage(db, 'CBP', { amount: '425', actualBalance: '24675', transactionId: 'Z0' }, m);
  assert.equal(out.status, 200);
  assert.equal(out.json.calc.commissionPaise, 425);
  assert.equal(out.json.wallet.currentBalancePaise, 2467925);
});

test('CBP rows with leftover actual balance still get 1% if commission is 0', async () => {
  const db = dbReady();
  const { rebuildCbpFromOpening } = require('../lib/service_wallet');
  await db.collection('cbc').insertOne({
    _id: 20,
    id: 1,
    amount: '425.00',
    amountNum: 425,
    amountPaise: 42500,
    commission: '0.00',
    commissionNum: 0,
    commissionPaise: 0,
    actualBalance: '24675.00',
    actualBalancePaise: 2467500,
    dateKey: '2026-09-01',
    transactionStatus: 'SUCCESS',
  });
  await rebuildCbpFromOpening(db);
  assert.equal(db._store.cbc[0].commissionPaise, 425);
  assert.equal(db._store.cbc[0].commission, '4.25');
});

test('CBP opening 25100 and old rows get 1% auto commission from remaining', async () => {
  const db = dbReady();
  const { rebuildCbpFromOpening, CBP_OPENING_PAISE } = require('../lib/service_wallet');
  await db.collection('cbc').insertOne({
    _id: 10,
    id: 1,
    amount: '425.00',
    amountNum: 425,
    commission: '0.00',
    commissionNum: 0,
    dateKey: '2026-09-01',
    transactionStatus: 'SUCCESS',
  });
  await db.collection('cbc').insertOne({
    _id: 11,
    id: 2,
    amount: '500.00',
    amountNum: 500,
    commission: '0.00',
    commissionNum: 0,
    dateKey: '2026-09-02',
    transactionStatus: 'SUCCESS',
  });
  const wallet = await rebuildCbpFromOpening(db);
  assert.equal(Number(wallet.totalCreditsPaise), CBP_OPENING_PAISE);
  const rows = db._store.cbc;
  assert.equal(rows[0].commissionPaise, 425);
  assert.equal(rows[0].previousBalancePaise, 2510000);
  assert.equal(rows[0].actualBalancePaise, 2510000 - 42500 + 425);
  assert.equal(rows[0].commission, '4.25');
  assert.equal(rows[1].previousBalancePaise, rows[0].actualBalancePaise);
  assert.equal(rows[1].commissionPaise, 500);
  assert.equal(Number(wallet.currentBalancePaise), rows[1].actualBalancePaise);
  assert.equal(Number(wallet.totalCommissionPaise), 925);
});

test('successful CBP amount cannot be edited, only reversed', async () => {
  const db = dbReady();
  const m = meta();
  await addMoney(db, 'CBP', { amount: '1000' }, m);
  const added = await cbc.add(db, { amount: '425', actualBalance: '585', transactionId: 'LOCK1' }, m);
  assert.equal(added.status, 200);
  const edit = await cbc.update(db, added.json.row.id, { amount: '200', actualBalance: '800' }, m, async () => null);
  assert.equal(edit.status, 400);
  assert.match(String(edit.json.error), /edit nahi/i);
  const wallet = await ensureWallet(db, 'CBP');
  assert.equal(wallet.currentBalancePaise, 57925);
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
  assert.equal(out.json.row.commission, '4.25');
  assert.notEqual(out.json.row.commission, '425.00');
  assert.notEqual(out.json.row.commission, '125.00');
  assert.equal(out.json.row.amount, '425.00');
  assert.equal(out.json.wallet.currentBalancePaise, 2467925);
});
