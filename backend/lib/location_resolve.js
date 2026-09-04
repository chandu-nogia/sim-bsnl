'use strict';

const { nextId } = require('./ids');

const DEFAULT_LOCATION = process.env.DEFAULT_LOCATION_NAME || 'Khatu Shyam Ji';

const ALIASES = {
  khatu: DEFAULT_LOCATION,
  'khatu shyam': DEFAULT_LOCATION,
  'khatu shyam ji': DEFAULT_LOCATION,
  'khatu shyamji': DEFAULT_LOCATION,
};

function normalizeName(name) {
  return String(name || '').trim().replace(/\s+/g, ' ');
}

function nameKey(name) {
  return normalizeName(name).toLowerCase();
}

function codeFromName(name) {
  const clean = String(name || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '')
    .slice(0, 10);
  return clean || 'LOC';
}

function displayName(raw) {
  const name = normalizeName(raw);
  return ALIASES[nameKey(name)] || name;
}

function locationMatchQuery(locationId) {
  const id = Number(locationId);
  if (!id) return { id: { $in: [] } };
  return { $or: [{ locationId: id }, { locationId: String(id) }] };
}

function rowBelongsToLocation(row, locationId) {
  return Number(row && row.locationId) === Number(locationId);
}

async function findLocationByName(db, rawName) {
  const name = displayName(rawName);
  if (!name) return null;
  const want = nameKey(name);
  const wantRaw = nameKey(rawName);
  const rows = await db.collection('locations').find().toArray();
  return (
    rows.find((r) => {
      const n = nameKey(r.name);
      const c = nameKey(r.code);
      return n === want || n === wantRaw || c === want || c === wantRaw;
    }) || null
  );
}

async function findOrCreateLocation(db, rawName) {
  const name = displayName(rawName);
  if (!name) return { error: 'Location likho' };
  const existing = await findLocationByName(db, name);
  if (existing) return { location: existing };
  const id = await nextId(db, 'locations');
  let code = codeFromName(name);
  const taken = await db.collection('locations').findOne({ code });
  if (taken) code = `${code}${id}`.replace(/[^A-Z0-9]/g, '').slice(0, 12) || `LOC${id}`;
  const now = new Date().toISOString();
  const location = {
    id,
    name,
    code,
    nameKey: nameKey(name),
    address: '',
    status: 'active',
    createdAt: now,
    updatedAt: now,
  };
  await db.collection('locations').insertOne(location);
  return { location };
}

async function resolveEmployeeLocation(db, body, fallback) {
  const fromId = Number.parseInt(String(body?.locationId ?? ''), 10) || 0;
  if (fromId) {
    const loc = await db.collection('locations').findOne({ id: fromId });
    if (loc) return { location: loc };
  }
  const assigned = Array.isArray(body?.assignedLocations)
    ? body.assignedLocations.map((v) => Number(v)).filter(Boolean)
    : [];
  if (assigned[0]) {
    const loc = await db.collection('locations').findOne({ id: assigned[0] });
    if (loc) return { location: loc };
  }
  const typed = normalizeName(body?.location || body?.locationName || '');
  const allowCreate = body?.createLocation === true || body?.createLocation === 'true';
  if (typed) {
    const existing = await findLocationByName(db, typed);
    if (existing) return { location: existing };
    if (!allowCreate) {
      return {
        needsCreate: true,
        name: displayName(typed),
        error: `Location "${displayName(typed)}" nahi mili. Confirm karke nayi location banao.`,
      };
    }
    return findOrCreateLocation(db, typed);
  }
  if (fallback && fallback.locationId) {
    const loc = await db.collection('locations').findOne({ id: Number(fallback.locationId) });
    if (loc) return { location: loc };
  }
  if (fallback && fallback.locationName) {
    const existing = await findLocationByName(db, fallback.locationName);
    if (existing) return { location: existing };
  }
  return { error: 'Location likho' };
}

async function previewLocation(db, rawName) {
  const name = displayName(rawName);
  if (!name) return { status: 400, json: { ok: false, error: 'Location likho' } };
  const existing = await findLocationByName(db, name);
  return {
    status: 200,
    json: {
      ok: true,
      exists: Boolean(existing),
      name,
      location: existing
        ? { id: Number(existing.id), name: existing.name, status: existing.status || 'active' }
        : null,
    },
  };
}

async function repairEmployeeLocations(db) {
  const users = await db.collection('users').find({ role: 'employee' }).toArray();
  for (const u of users) {
    const typed = normalizeName(u.locationName || '');
    let loc = null;
    if (typed) loc = (await findOrCreateLocation(db, typed)).location;
    if (!loc && u.locationId) {
      loc = await db.collection('locations').findOne({ id: Number(u.locationId) });
    }
    if (!loc && Array.isArray(u.assignedLocations) && u.assignedLocations[0]) {
      loc = await db.collection('locations').findOne({ id: Number(u.assignedLocations[0]) });
    }
    if (!loc) continue;
    const id = Number(loc.id);
    if (Number(u.locationId) === id && Array.isArray(u.assignedLocations) && u.assignedLocations[0] === id) {
      if (u.locationName === loc.name) continue;
    }
    await db.collection('users').updateOne(
      { email: u.email },
      {
        $set: {
          locationId: id,
          assignedLocations: [id],
          locationName: loc.name,
        },
      },
    );
  }
}

module.exports = {
  normalizeName,
  nameKey,
  displayName,
  codeFromName,
  locationMatchQuery,
  rowBelongsToLocation,
  findLocationByName,
  findOrCreateLocation,
  resolveEmployeeLocation,
  repairEmployeeLocations,
  previewLocation,
};
