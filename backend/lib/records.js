'use strict';

const { nextId } = require('./ids');
const { logActivity } = require('./activity');
const { mongoListQuery, applyTextSearch } = require('./rbac');
const { locationMatchQuery } = require('./location_resolve');
const { withAlive } = require('./alive');
const { dateKeyOf, applyDateRange, applyAmountRange, sortSpec } = require('./dates');
const { moneyNumber, moneyText, parseAmount } = require('./password');
const { publicConfig } = require('./commission');
const { applyUsage, reverseUsage, isFailedStatus, snapshotBoth } = require('./service_wallet');

function moneyFields(b) {
  const parsed = parseAmount(b.amount, { required: false, allowZero: true });
  const amount = parsed.ok ? parsed.text : String(b.amount ?? '').trim();
  const amountNum = parsed.ok ? parsed.value : moneyNumber(b.amount);
  const actualRaw = b.actualBalance ?? b.balance;
  const actual = actualRaw === undefined || actualRaw === '' ? { ok: true, text: '', value: 0 } : parseAmount(actualRaw, { required: false, allowZero: true });
  return {
    amount,
    amountNum,
    actualBalance: actual.ok ? actual.text : String(actualRaw ?? ''),
    commission: b.commission === undefined || b.commission === '' ? undefined : String(b.commission),
    commissionNum: b.commissionNum,
    balance: actual.ok ? actual.text : '',
    balanceNum: actual.ok ? actual.value : 0,
    _amountError: parsed.ok ? null : parsed.error,
    _actualError: actual.ok ? null : actual.error,
  };
}

function publicCbc(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    date: row.date || '',
    dateKey: row.dateKey || dateKeyOf(row.date),
    name: row.name || '',
    mobile: row.mobile || '',
    landline: row.landline || '',
    amount: row.amount || moneyText(row.amountNum),
    amountNum: moneyNumber(row.amountNum ?? row.amount),
    commission: moneyText(
      row.commissionPaise != null && row.commissionPaise !== ''
        ? Number(row.commissionPaise) / 100
        : (row.commissionNum ?? row.commission),
    ),
    commissionNum: moneyNumber(
      row.commissionPaise != null && row.commissionPaise !== ''
        ? Number(row.commissionPaise) / 100
        : (row.commissionNum ?? row.commission),
    ),
    previousBalance: row.previousBalance || moneyText((row.previousBalancePaise || 0) / 100),
    expectedBalance: row.expectedBalance || moneyText((row.expectedBalancePaise || 0) / 100),
    actualBalance: row.actualBalance || row.balance || moneyText(row.balanceNum),
    balance: row.balance || row.actualBalance || moneyText(row.balanceNum),
    balanceNum: moneyNumber(row.balanceNum ?? row.actualBalance ?? row.balance),
    transactionStatus: row.transactionStatus || (row.deletedAt ? 'REVERSED' : 'SUCCESS'),
    transactionId: row.transactionId || '',
    note: row.note || '',
    createdBy: row.createdBy || '',
    employeeId: row.employeeId ? Number(row.employeeId) : null,
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
  };
}

function pickCbc(body) {
  const b = body && typeof body === 'object' ? body : {};
  const date = String(b.date ?? '').trim();
  return {
    date,
    dateKey: dateKeyOf(date),
    name: String(b.name ?? '').trim(),
    mobile: String(b.mobile ?? '').trim(),
    landline: String(b.landline ?? '').trim(),
    ...moneyFields(b),
    transactionId: String(b.transactionId ?? b.txnId ?? '').trim(),
    note: String(b.note ?? b.remarks ?? '').trim(),
  };
}

function validateCbc(row) {
  return row._amountError || row._actualError || null;
}

function publicCtopup(row) {
  const id = Number(row.id);
  return {
    id,
    rowIndex: id,
    locationId: row.locationId ? Number(row.locationId) : null,
    locationName: row.locationName || '',
    date: row.date || '',
    dateKey: row.dateKey || dateKeyOf(row.date),
    name: row.name || '',
    number: row.number || '',
    amount: row.amount || moneyText(row.amountNum),
    amountNum: moneyNumber(row.amountNum ?? row.amount),
    type: row.type || '',
    commission: row.commission || moneyText(row.commissionNum),
    commissionNum: moneyNumber(row.commissionNum ?? row.commission),
    previousBalance: row.previousBalance || moneyText((row.previousBalancePaise || 0) / 100),
    expectedBalance: row.expectedBalance || moneyText((row.expectedBalancePaise || 0) / 100),
    actualBalance: row.actualBalance || row.balance || moneyText(row.balanceNum),
    balance: row.balance || row.actualBalance || moneyText(row.balanceNum),
    balanceNum: moneyNumber(row.balanceNum ?? row.actualBalance ?? row.balance),
    transactionStatus: row.transactionStatus || (row.deletedAt ? 'REVERSED' : 'SUCCESS'),
    status: row.status || 'Pending',
    transactionId: row.transactionId || '',
    note: row.note || '',
    createdBy: row.createdBy || '',
    employeeId: row.employeeId ? Number(row.employeeId) : null,
    createdAt: row.createdAt || '',
    updatedAt: row.updatedAt || '',
  };
}

function pickCtopup(body) {
  const b = body && typeof body === 'object' ? body : {};
  const date = String(b.date ?? '').trim();
  return {
    date,
    dateKey: dateKeyOf(date),
    name: String(b.name ?? '').trim(),
    number: String(b.number ?? b.mobile ?? '').trim(),
    type: String(b.type ?? b.topupType ?? '').trim(),
    ...moneyFields(b),
    status: String(b.status ?? b.paymentStatus ?? 'Pending').trim() || 'Pending',
    transactionId: String(b.transactionId ?? b.txnId ?? b.reference ?? '').trim(),
    note: String(b.note ?? b.remarks ?? '').trim(),
  };
}

function validateCtopup(row) {
  return row._amountError || row._actualError || null;
}

function actorLabel(meta) {
  return meta.name || meta.email || 'Staff';
}

function applyCalc(row, calc) {
  row.commission = calc.commission;
  row.commissionNum = calc.commissionPaise / 100;
  row.commissionPaise = calc.commissionPaise;
  row.previousBalance = calc.previous;
  row.previousBalancePaise = calc.previousPaise;
  row.expectedBalance = calc.expected;
  row.expectedBalancePaise = calc.expectedPaise;
  row.actualBalance = calc.actual;
  row.actualBalancePaise = calc.actualPaise;
  row.amountPaise = calc.amountPaise;
  row.balance = calc.actual;
  row.balanceNum = calc.actualPaise / 100;
  row.walletApplied = true;
  row.transactionStatus = 'SUCCESS';
  return row;
}

async function applyRowUsage(db, section, row, meta, ref) {
  if (!(moneyNumber(row.amountNum) > 0) || isFailedStatus(row.status)) {
    row.walletApplied = false;
    row.transactionStatus = isFailedStatus(row.status) ? 'FAILED' : 'SUCCESS';
    return { status: 200 };
  }
  const usage = await applyUsage(db, section, {
    amount: row.amount,
    actualBalance: row.actualBalance || row.balance,
    transactionId: ref,
    recordId: ref,
    status: row.status,
    date: row.dateKey || row.date,
  }, meta);
  if (usage.status !== 200) return usage;
  if (usage.json.calc) applyCalc(row, usage.json.calc);
  return { status: 200 };
}

function makeCrud(collection, pick, validate, toPublic, section) {
  return {
    async list(db, scope = {}) {
      let q = withAlive(mongoListQuery(scope));
      q = applyTextSearch(q, ['name', 'mobile', 'number', 'transactionId', 'note', 'type'], scope.q);
      q = applyDateRange(q, scope.from, scope.to);
      q = applyAmountRange(q, scope.minAmount, scope.maxAmount);
      const status = String(scope.status || '').trim();
      if (status) q.status = status;
      const typ = String(scope.type || '').trim();
      if (typ && typ !== 'All') q.type = typ;
      const page = Math.max(1, Number(scope.page) || 1);
      const limit = Math.min(500, Math.max(20, Number(scope.limit) || 200));
      const skip = (page - 1) * limit;
      const col = db.collection(collection);
      const total = await col.countDocuments(q);
      const rows = await col.find(q).sort(sortSpec(scope)).skip(skip).limit(limit).toArray();
      const snap = await snapshotBoth(db);
      const svc = section === 'ctopup' ? snap.ctopup : snap.cbp;
      return {
        rows: rows.map(toPublic),
        total,
        page,
        limit,
        walletAmount: svc.totalCreditsNum,
        remainingBalance: svc.currentBalanceNum,
        previousBalance: svc.currentBalance,
        cbpBalance: snap.cbpBalance,
        ctopupBalance: snap.ctopupBalance,
        totalCommission: svc.totalCommissionNum,
        totalAdded: svc.totalCreditsNum,
        totalUsed: svc.totalTransactionAmountNum,
        ...publicConfig(),
      };
    },
    async add(db, body, meta) {
      const picked = pick(body);
      const err = validate(picked);
      if (err) return { status: 400, json: { ok: false, error: err } };
      delete picked._amountError;
      delete picked._actualError;
      const row = picked;
      if (row.transactionId && body?.force !== true) {
        const dup = await db.collection(collection).findOne(withAlive({
          locationId: Number(meta.locationId),
          transactionId: row.transactionId,
        }));
        if (dup) {
          return {
            status: 409,
            json: { ok: false, error: 'Is location mein ye Transaction ID pehle se hai', duplicate: true },
          };
        }
      }
      const id = await nextId(db, collection);
      const ref = row.transactionId || String(id);
      const applied = await applyRowUsage(db, section, row, meta, ref);
      if (applied.status !== 200) return applied;
      const now = new Date().toISOString();
      const saved = {
        id,
        ...row,
        locationId: Number(meta.locationId),
        locationName: meta.locationName || '',
        createdBy: meta.email || '',
        employeeId: meta.userId ? Number(meta.userId) : null,
        createdAt: now,
        updatedAt: now,
      };
      try {
        await db.collection(collection).insertOne(saved);
      } catch (e) {
        if (row.walletApplied) {
          await reverseUsage(db, section, { ...saved, id }, meta);
        }
        throw e;
      }
      const moneyBit = row.amount ? ` of ₹${row.amount}` : '';
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        name: meta.name,
        action: 'add',
        section,
        locationId: saved.locationId,
        locationName: saved.locationName,
        detail: `${actorLabel(meta)} added ${section === 'ctopup' ? 'C-TopUp transaction' : 'CBP record'}${moneyBit} in ${saved.locationName}`,
      });
      const fresh = await db.collection(collection).findOne({ id });
      return { status: 200, json: { ok: true, row: toPublic(fresh || saved) } };
    },
    async update(db, idRaw, body, meta, assertRow) {
      const id = Number.parseInt(String(idRaw), 10);
      const locId = Number(meta.locationId);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      if (!locId) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
      const existing = await db.collection(collection).findOne({ id, ...locationMatchQuery(locId) });
      if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      const blocked = await assertRow(existing);
      if (blocked) return blocked;
      if (existing.transactionStatus === 'REVERSED') {
        return { status: 400, json: { ok: false, error: 'Reversed transaction edit nahi hoti' } };
      }
      const picked = pick({ ...toPublic(existing), ...body });
      const err = validate(picked);
      if (err) return { status: 400, json: { ok: false, error: err } };
      delete picked._amountError;
      delete picked._actualError;
      const row = picked;
      const moneyChanged = moneyNumber(row.amountNum) !== moneyNumber(existing.amountNum ?? existing.amount)
        || String(row.actualBalance || row.balance) !== String(existing.actualBalance || existing.balance)
        || String(row.status || '') !== String(existing.status || '');
      const wasApplied = existing.walletApplied !== false
        && existing.transactionStatus !== 'FAILED'
        && existing.transactionStatus !== 'REVERSED'
        && !isFailedStatus(existing.status);
      const shouldApply = moneyNumber(row.amountNum) > 0 && !isFailedStatus(row.status);
      if (moneyChanged && wasApplied) {
        const rev = await reverseUsage(db, section, existing, meta);
        if (rev.status !== 200) return rev;
      }
      if (shouldApply && (moneyChanged || !wasApplied)) {
        const usage = await applyRowUsage(db, section, row, meta, `${row.transactionId || existing.id}-U${Date.now()}`);
        if (usage.status !== 200) {
          if (moneyChanged && wasApplied) {
            await applyUsage(db, section, {
              amount: existing.amount,
              actualBalance: existing.actualBalance || existing.balance,
              transactionId: `${existing.transactionId || existing.id}-RESTORE`,
              status: existing.status,
              date: existing.dateKey || existing.date,
            }, meta);
          }
          return usage;
        }
      } else if (!shouldApply) {
        row.walletApplied = false;
        row.transactionStatus = isFailedStatus(row.status) ? 'FAILED' : existing.transactionStatus || 'SUCCESS';
      }
      if (!moneyChanged) {
        row.commission = existing.commission;
        row.commissionNum = existing.commissionNum;
        row.commissionPaise = existing.commissionPaise;
        row.previousBalance = existing.previousBalance;
        row.previousBalancePaise = existing.previousBalancePaise;
        row.expectedBalance = existing.expectedBalance;
        row.expectedBalancePaise = existing.expectedBalancePaise;
        row.actualBalance = existing.actualBalance;
        row.actualBalancePaise = existing.actualBalancePaise;
        row.balance = existing.balance;
        row.balanceNum = existing.balanceNum;
        row.walletApplied = existing.walletApplied;
        row.transactionStatus = existing.transactionStatus;
      }
      const saved = {
        ...row,
        id,
        locationId: Number(existing.locationId),
        locationName: existing.locationName || meta.locationName || '',
        createdBy: existing.createdBy || meta.email || '',
        employeeId: existing.employeeId || (meta.userId ? Number(meta.userId) : null),
        createdAt: existing.createdAt || '',
        updatedAt: new Date().toISOString(),
      };
      await db.collection(collection).updateOne({ _id: existing._id }, { $set: saved });
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        name: meta.name,
        action: 'update',
        section,
        locationId: saved.locationId,
        locationName: saved.locationName,
        detail: `${actorLabel(meta)} updated ${section === 'ctopup' ? 'C-TopUp' : 'CBP'} ₹${moneyText(existing.amountNum)} → ₹${row.amount} in ${saved.locationName}`,
      });
      const fresh = await db.collection(collection).findOne({ id });
      return { status: 200, json: { ok: true, row: toPublic(fresh || saved) } };
    },
    async remove(db, idRaw, meta, assertRow) {
      const id = Number.parseInt(String(idRaw), 10);
      const locId = Number(meta.locationId);
      if (!id) return { status: 400, json: { ok: false, error: 'Invalid id' } };
      if (!locId) return { status: 400, json: { ok: false, error: 'Jagah choose karo' } };
      const existing = await db.collection(collection).findOne({ id, ...locationMatchQuery(locId) });
      if (!existing) return { status: 404, json: { ok: false, error: 'Entry nahi mili' } };
      const blocked = await assertRow(existing);
      if (blocked) return blocked;
      const rev = await reverseUsage(db, section, existing, meta);
      if (rev.status !== 200) return rev;
      await db.collection(collection).updateOne(
        { _id: existing._id },
        {
          $set: {
            transactionStatus: 'REVERSED',
            walletApplied: false,
            updatedAt: new Date().toISOString(),
            reversedBy: meta.email || '',
            reversedAt: new Date().toISOString(),
          },
        },
      );
      await logActivity(db, {
        email: meta.email,
        role: meta.role,
        name: meta.name,
        action: 'update',
        section,
        locationId: existing.locationId,
        locationName: existing.locationName || '',
        detail: `${actorLabel(meta)} reversed ${section === 'ctopup' ? 'C-TopUp' : 'CBP'} record in ${existing.locationName || ''}`,
      });
      const fresh = await db.collection(collection).findOne({ id });
      return { status: 200, json: { ok: true, reversed: true, row: toPublic(fresh || existing) } };
    },
  };
}

const cbc = makeCrud('cbc', pickCbc, validateCbc, publicCbc, 'cbc');
const ctopup = makeCrud('ctopup', pickCtopup, validateCtopup, publicCtopup, 'ctopup');

module.exports = { cbc, ctopup };
