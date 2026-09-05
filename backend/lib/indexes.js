'use strict';

async function ensureIndexes(db) {
  const jobs = [
    db.collection('users').createIndex({ email: 1 }, { unique: true }),
    db.collection('users').createIndex({ role: 1, status: 1 }),
    db.collection('users').createIndex({ name: 1 }),
    db.collection('users').createIndex({ mobile: 1 }),
    db.collection('users').createIndex({ locationId: 1, status: 1 }),
    db.collection('locations').createIndex({ id: 1 }, { unique: true }),
    db.collection('locations').createIndex({ code: 1 }),
    db.collection('locations').createIndex({ status: 1 }),
    db.collection('locations').createIndex({ nameKey: 1 }),
    db.collection('stock').createIndex({ locationId: 1 }, { unique: true }),
    db.collection('closing').createIndex({ locationId: 1, date: -1 }),
  ];
  for (const col of ['sims', 'cbc', 'ctopup']) {
    jobs.push(db.collection(col).createIndex({ locationId: 1, id: 1 }));
    jobs.push(db.collection(col).createIndex({ createdAt: 1 }));
    jobs.push(db.collection(col).createIndex({ employeeId: 1 }));
    jobs.push(db.collection(col).createIndex({ createdBy: 1 }));
    jobs.push(db.collection(col).createIndex({ locationId: 1, deletedAt: 1 }));
    jobs.push(db.collection(col).createIndex({ locationId: 1, mobile: 1 }));
    jobs.push(db.collection(col).createIndex({ dateKey: 1, id: -1 }));
  }
  jobs.push(db.collection('cbc').createIndex({ locationId: 1, transactionId: 1 }));
  jobs.push(db.collection('ctopup').createIndex({ locationId: 1, transactionId: 1 }));
  jobs.push(db.collection('ctopup').createIndex({ locationId: 1, type: 1 }));
  jobs.push(db.collection('wallet_txns').createIndex({ locationId: 1, id: 1 }));
  jobs.push(db.collection('wallet_txns').createIndex({ txnId: 1 }));
  jobs.push(db.collection('wallet_txns').createIndex({ dateKey: 1, id: -1 }));
  jobs.push(db.collection('wallet_txns').createIndex({ locationId: 1, deletedAt: 1 }));
  jobs.push(db.collection('wallet_txns').createIndex({ transactionType: 1, createdAt: -1 }));
  jobs.push(db.collection('wallet_txns').createIndex({ amountNum: 1 }));
  jobs.push(db.collection('activity').createIndex({ at: -1 }));
  jobs.push(db.collection('activity').createIndex({ locationId: 1, at: -1 }));
  jobs.push(db.collection('activity').createIndex({ email: 1, at: -1 }));
  jobs.push(db.collection('activity').createIndex({ action: 1, at: -1 }));
  const results = await Promise.allSettled(jobs);
  for (const r of results) {
    if (r.status === 'rejected') {
      console.warn('Index skip:', r.reason?.message || r.reason);
    }
  }
}

module.exports = { ensureIndexes };
