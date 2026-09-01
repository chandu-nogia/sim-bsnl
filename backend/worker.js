'use strict';

const { handleApi } = require('./lib/api');

module.exports = {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) {
      return handleApi(request, env);
    }
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }
    return new Response(
      JSON.stringify({
        ok: true,
        message: 'BSNL SIM API. Flutter UI alag folder: bsnl_sim_portal',
      }),
      { status: 200, headers: { 'Content-Type': 'application/json; charset=utf-8' } },
    );
  },
};
