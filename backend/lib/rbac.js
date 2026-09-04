'use strict';

const { locationMatchQuery, rowBelongsToLocation } = require('./location_resolve');

function assignedIds(user) {
  if (!user) return [];
  if (user.role === 'admin') return null;
  const fromArr = Array.isArray(user.assignedLocations)
    ? user.assignedLocations.map((v) => Number(v)).filter(Boolean)
    : [];
  const one = Number(user.locationId);
  return [...new Set([...fromArr, ...(one ? [one] : [])])];
}

function requestedLocationId(req, body) {
  const raw =
    (body && body.locationId) ||
    req.headers['x-location-id'] ||
    req.query?.locationId;
  return Number.parseInt(String(raw ?? ''), 10) || 0;
}

function listScope(req) {
  const ids = assignedIds(req.user);
  if (ids !== null) {
    if (!ids.length) return { error: 'Is account ki koi jagah nahi', status: 403 };
    return { locationId: ids[0] };
  }
  const requested = requestedLocationId(req, {});
  if (requested) return { locationId: requested };
  return { all: true };
}

function writeScope(req, body) {
  const ids = assignedIds(req.user);
  if (ids !== null) {
    if (!ids.length) return { error: 'Is account ki koi jagah nahi', status: 403 };
    return { locationId: ids[0] };
  }
  const requested = requestedLocationId(req, body || {});
  if (!requested) return { error: 'Jagah choose karo', status: 400 };
  return { locationId: requested };
}

function assertRowLocation(req, row, locationId) {
  const ids = assignedIds(req.user);
  const loc = Number(locationId || (ids && ids[0]) || 0);
  if (ids !== null) {
    if (!ids.length || !rowBelongsToLocation(row, ids[0])) {
      return { status: 403, json: { ok: false, error: 'Ye entry dusri jagah ki hai' } };
    }
    return null;
  }
  if (loc && !rowBelongsToLocation(row, loc)) {
    return { status: 403, json: { ok: false, error: 'Ye entry dusri jagah ki hai' } };
  }
  return null;
}

function mongoListQuery(scope) {
  if (scope.empty) return { id: { $in: [] } };
  if (scope.all) return {};
  if (scope.locationId) return locationMatchQuery(scope.locationId);
  if (scope.locationIds && scope.locationIds.length) {
    const nums = scope.locationIds.map(Number).filter(Boolean);
    if (!nums.length) return { id: { $in: [] } };
    return {
      $or: [{ locationId: { $in: nums } }, { locationId: { $in: nums.map(String) } }],
    };
  }
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
  requestedLocationId,
  listScope,
  writeScope,
  assertRowLocation,
  mongoListQuery,
  applyTextSearch,
};
