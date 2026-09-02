'use strict';

async function nextId(db, key) {
  const result = await db.collection('counters').findOneAndUpdate(
    { _id: key },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' },
  );
  const seq = result && (result.seq ?? result.value?.seq);
  return Number(seq) || 1;
}

module.exports = { nextId };
