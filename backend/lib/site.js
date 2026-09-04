'use strict';

const { locationMatchQuery } = require('./location_resolve');

const OWNER_EMAIL = (process.env.OWNER_EMAIL || process.env.EMPLOYEE_EMAIL || 'chandu20@gmail.com')
  .trim()
  .toLowerCase();
const OWNER_PASSWORD = process.env.OWNER_PASSWORD || process.env.EMPLOYEE_PASSWORD || 'chandu@20khatu';
const LOCATION_NAME = process.env.DEFAULT_LOCATION_NAME || 'Khatushyamji';

function isOwnerEmail(email) {
  return String(email || '').trim().toLowerCase() === OWNER_EMAIL;
}

async function khatuLocation(db) {
  const locCol = db.collection('locations');
  let loc = await locCol.findOne({
    $or: [
      { code: 'KHATU' },
      { name: LOCATION_NAME },
      { name: 'Khatu Shyam Ji' },
      { name: 'Khatu' },
      { email: OWNER_EMAIL },
    ],
  });
  if (!loc) {
    loc = await locCol.findOne({ id: 1 });
  }
  return loc;
}

function khatuQuery(loc) {
  const id = Number(loc && loc.id) || 1;
  return locationMatchQuery(id);
}

module.exports = {
  OWNER_EMAIL,
  OWNER_PASSWORD,
  LOCATION_NAME,
  isOwnerEmail,
  khatuLocation,
  khatuQuery,
};
