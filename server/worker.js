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
      'Flutter web build missing. Run: flutter build web --release',
      { status: 200, headers: { 'Content-Type': 'text/plain; charset=utf-8' } },
    );
  },
};
