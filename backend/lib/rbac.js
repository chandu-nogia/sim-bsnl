'use strict';

const { locationMatchQuery, rowBelongsToLocation } = require('./location_resolve');

function assignedIds(user) {
  const one = Number(user && user.locationId);
  return one ? [one] : [];
}

function listScope(req) {
  const ids = assignedIds(req.user);
  if (!ids.length) return { error: 'Khatushyamji location missing', status: 403 };
  return { locationId: ids[0] };
}

function writeScope(req) {
  return listScope(req);
}

function assertRowLocation(req, row, locationId) {
  const loc = Number(locationId || (req.user && req.user.locationId) || 0);
  if (!loc || !rowBelongsToLocation(row, loc)) {
    return { status: 403, json: { ok: false, error: 'Ye entry is location ki nahi hai' } };
  }
  return null;
}

function mongoListQuery(scope) {
  if (scope.empty) return { id: { $in: [] } };
  if (scope.locationId) return locationMatchQuery(scope.locationId);
  return { id: { $in: [] } };
}

function applyTextSearch(q, fields, search) {
  const s = String(search || '').trim();
  if (!s || !fields.length) return q;
  const rx = { $regex: s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
  const searchOr = fields.map((f) => ({ [f]: rx }));
  const locOr = q.$or;
  if (locOr) {
    const next = { ...q };
    delete next.$or;
    next.$and = [{ $or: locOr }, { $or: searchOr }];
    return next;
  }
  q.$or = searchOr;
  return q;
}

module.exports = {
  assignedIds,
  listScope,
  writeScope,
  assertRowLocation,
  mongoListQuery,
  applyTextSearch,
};
