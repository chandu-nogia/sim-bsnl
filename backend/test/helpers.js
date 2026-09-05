'use strict';

function matchValue(docVal, cond) {
  if (cond && typeof cond === 'object' && !Array.isArray(cond) && !(cond instanceof RegExp)) {
    if (cond.$exists === false) return docVal === undefined;
    if (cond.$exists === true) return docVal !== undefined;
    if (cond.$in) return cond.$in.includes(docVal);
    if (cond.$nin) return !cond.$nin.includes(docVal);
    if (cond.$gte !== undefined || cond.$lte !== undefined || cond.$gt !== undefined || cond.$lt !== undefined) {
      const n = docVal;
      if (cond.$gte !== undefined && !(n >= cond.$gte)) return false;
      if (cond.$lte !== undefined && !(n <= cond.$lte)) return false;
      if (cond.$gt !== undefined && !(n > cond.$gt)) return false;
      if (cond.$lt !== undefined && !(n < cond.$lt)) return false;
      return true;
    }
    if (cond.$regex) {
      const rx = new RegExp(cond.$regex, cond.$options || '');
      return rx.test(String(docVal ?? ''));
    }
    if (cond.$type) {
      if (cond.$type === 'string' && typeof docVal !== 'string') return false;
      if (cond.$gt !== undefined && !(docVal > cond.$gt)) return false;
    }
    if (Object.keys(cond).some((k) => k.startsWith('$'))) return true;
  }
  if (cond && typeof cond === 'object' && cond.$or) return matchDoc({ v: docVal }, { $or: cond.$or });
  return docVal === cond;
}

function matchDoc(doc, query) {
  if (!query || typeof query !== 'object') return true;
  if (query.$and) return query.$and.every((q) => matchDoc(doc, q));
  if (query.$or) return query.$or.some((q) => matchDoc(doc, q));
  for (const [k, v] of Object.entries(query)) {
    if (k.startsWith('$')) continue;
    if (!matchValue(doc[k], v)) return false;
  }
  return true;
}

function createMemoryDb() {
  const store = {};
  let oid = 1;

  function col(name) {
    if (!store[name]) store[name] = [];
    const rows = store[name];
    const api = {
      async findOne(q) {
        return rows.find((r) => matchDoc(r, q)) || null;
      },
      async insertOne(doc) {
        if (doc._id === undefined) doc._id = oid++;
        const row = doc;
        rows.push(row);
        return { insertedId: row._id };
      },
      async updateOne(q, upd) {
        const row = rows.find((r) => matchDoc(r, q));
        if (!row) return { matchedCount: 0, modifiedCount: 0 };
        if (upd.$set) Object.assign(row, upd.$set);
        if (upd.$inc) {
          for (const [k, v] of Object.entries(upd.$inc)) row[k] = (Number(row[k]) || 0) + v;
        }
        return { matchedCount: 1, modifiedCount: 1 };
      },
      async findOneAndUpdate(q, upd, opts = {}) {
        let row = rows.find((r) => matchDoc(r, q));
        if (!row && opts.upsert) {
          row = { ...q };
          if (row._id === undefined) row._id = q._id !== undefined ? q._id : oid++;
          rows.push(row);
        }
        if (!row) return { value: null };
        if (upd.$set) Object.assign(row, upd.$set);
        if (upd.$inc) {
          for (const [k, v] of Object.entries(upd.$inc)) row[k] = (Number(row[k]) || 0) + v;
        }
        return { value: { ...row } };
      },
      async countDocuments(q = {}) {
        return rows.filter((r) => matchDoc(r, q)).length;
      },
      find(q = {}) {
        let list = rows.filter((r) => matchDoc(r, q)).map((r) => ({ ...r }));
        const chain = {
          project() { return chain; },
          sort(spec) {
            const keys = Object.entries(spec || {});
            list.sort((a, b) => {
              for (const [k, dir] of keys) {
                if (a[k] < b[k]) return dir < 0 ? 1 : -1;
                if (a[k] > b[k]) return dir < 0 ? -1 : 1;
              }
              return 0;
            });
            return chain;
          },
          skip(n) { list = list.slice(n); return chain; },
          limit(n) { list = list.slice(0, n); return chain; },
          async toArray() { return list; },
        };
        return chain;
      },
      async createIndex() { return name; },
    };
    return api;
  }

  return {
    collection: col,
    _store: store,
    seedKhatu() {
      store.locations = [{
        _id: 1,
        id: 1,
        code: 'KHATU',
        name: 'Khatushyamji',
        status: 'active',
      }];
    },
  };
}

function meta() {
  return { email: 'chandu20@gmail.com', name: 'Owner', role: 'owner', locationId: 1, locationName: 'Khatushyamji' };
}

module.exports = { createMemoryDb, meta };
