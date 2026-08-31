'use strict';

const { MongoClient } = require('mongodb');

let clientPromise;

function mongoConfig(env) {
  const uri = (env && env.MONGODB_URI) || process.env.MONGODB_URI;
  const dbName =
    (env && env.MONGODB_DB) || process.env.MONGODB_DB || 'bsnl_sim';
  if (!uri) {
    throw new Error(
      'MONGODB_URI missing. Atlas se connection string lo, server/.env mein rakho.',
    );
  }
  return { uri, dbName };
}

async function getDb(env) {
  const { uri, dbName } = mongoConfig(env);
  if (!clientPromise) {
    const client = new MongoClient(uri, { serverSelectionTimeoutMS: 8000 });
    clientPromise = client.connect();
  }
  const client = await clientPromise;
  return client.db(dbName);
}

module.exports = { getDb, mongoConfig };
