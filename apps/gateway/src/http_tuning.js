const KEEP_ALIVE_MS = 95_000;
const HEADERS_MS = KEEP_ALIVE_MS + 1_000;

function applyKeepAlive(server) {
  server.keepAliveTimeout = KEEP_ALIVE_MS;
  server.headersTimeout = HEADERS_MS;
  return server;
}

module.exports = { applyKeepAlive, KEEP_ALIVE_MS, HEADERS_MS };
