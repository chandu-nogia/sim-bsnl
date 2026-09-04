'use strict';

const assert = require('assert');
const rbac = require('../lib/rbac');
const { nameKey, displayName, locationMatchQuery, rowBelongsToLocation } = require('../lib/location_resolve');

assert.strictEqual(displayName('khatu'), 'Khatu Shyam Ji');
assert.strictEqual(nameKey('  Sikar  '), 'sikar');

const khatuQ = locationMatchQuery(1);
assert.deepStrictEqual(khatuQ.$or[0], { locationId: 1 });
assert.ok(rowBelongsToLocation({ locationId: 1 }, 1));
assert.ok(!rowBelongsToLocation({ locationId: 2 }, 1));

const emp = { role: 'employee', locationId: 2, assignedLocations: [2] };
const req = {
  user: emp,
  headers: { 'x-location-id': '1' },
  query: { locationId: '1' },
};
assert.strictEqual(rbac.listScope(req).locationId, 2);
assert.strictEqual(rbac.writeScope(req, { locationId: 1 }).locationId, 2);
assert.ok(rbac.assertRowLocation(req, { locationId: 1 }, 2));
assert.strictEqual(rbac.assertRowLocation(req, { locationId: 2 }, 2), null);

const adminReq = { user: { role: 'admin' }, headers: {}, query: { locationId: '3' } };
assert.strictEqual(rbac.listScope(adminReq).locationId, 3);
const emptyAdmin = { user: { role: 'admin' }, headers: {}, query: {} };
assert.strictEqual(rbac.listScope(emptyAdmin).all, true);
assert.deepStrictEqual(rbac.mongoListQuery({ all: true }), {});

console.log('isolation checks ok');
