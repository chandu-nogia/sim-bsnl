'use strict';

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
  const requested = requestedLocationId(req, {});
  if (ids === null) {
    return requested ? { locationId: requested } : {};
  }
  if (!ids.length) return { error: 'Is account ki koi jagah nahi', status: 403 };
  if (requested) {
    if (!ids.includes(requested)) {
      return { error: 'Is jagah ki permission nahi', status: 403 };
    }
    return { locationId: requested };
  }
  if (ids.length === 1) return { locationId: ids[0] };
  return { locationIds: ids };
}

function writeScope(req, body) {
  const ids = assignedIds(req.user);
  let requested = requestedLocationId(req, body || {});
  if (ids === null) {
    if (!requested) return { error: 'Jagah choose karo', status: 400 };
    return { locationId: requested };
  }
  if (!requested && ids.length === 1) requested = ids[0];
  if (!requested || !ids.includes(requested)) {
    return { error: 'Is jagah ki permission nahi', status: 403 };
  }
  return { locationId: requested };
}

function assertRowLocation(req, row) {
  const ids = assignedIds(req.user);
  if (ids === null) return null;
  if (!ids.includes(Number(row.locationId))) {
    return { status: 403, json: { ok: false, error: 'Ye entry dusri jagah ki hai' } };
  }
  return null;
}

function mongoListQuery(scope) {
  if (scope.locationId) return { locationId: Number(scope.locationId) };
  if (scope.locationIds && scope.locationIds.length) {
    return { locationId: { $in: scope.locationIds.map(Number) } };
  }
  return {};
}

module.exports = {
  assignedIds,
  requestedLocationId,
  listScope,
  writeScope,
  assertRowLocation,
  mongoListQuery,
};
