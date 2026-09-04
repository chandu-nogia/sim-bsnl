'use strict';

function notDeleted() {
  return { $or: [{ deletedAt: { $exists: false } }, { deletedAt: null }] };
}

function withAlive(query) {
  const q = query && typeof query === 'object' ? query : {};
  return { $and: [q, notDeleted()] };
}

function isDeleted(row) {
  return Boolean(row && row.deletedAt);
}

module.exports = { notDeleted, withAlive, isDeleted };
