'use strict';

const assert = require('assert');
const rbac = require('../lib/rbac');
const { locationMatchQuery, rowBelongsToLocation } = require('../lib/location_resolve');

const khatuQ = locationMatchQuery(1);
assert.deepStrictEqual(khatuQ.$or[0], { locationId: 1 });
assert.ok(rowBelongsToLocation({ locationId: 1 }, 1));
assert.ok(!rowBelongsToLocation({ locationId: 2 }, 1));

const ownerReq = { user: { locationId: 1, email: 'chandu20@gmail.com' } };
assert.strictEqual(rbac.listScope(ownerReq).locationId, 1);
assert.strictEqual(rbac.writeScope(ownerReq).locationId, 1);
assert.ok(rbac.assertRowLocation(ownerReq, { locationId: 2 }, 1));
assert.strictEqual(rbac.assertRowLocation(ownerReq, { locationId: 1 }, 1), null);

const missing = { user: {} };
assert.ok(rbac.listScope(missing).error);

console.log('isolation checks ok');
