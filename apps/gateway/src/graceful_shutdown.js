function createGracefulShutdown({
  server,
  maxWaitMs = 9000,
  pollMs = 20,
  exit = (code) => process.exit(code),
  log = (msg) => console.log(msg),
} = {}) {
  let active = 0;
  let stopping = false;
  const tasks = new Set();

  if (server) {
    server.on("request", (req, res) => {
      active += 1;
      let done = false;
      const end = () => {
        if (done) return;
        done = true;
        active -= 1;
      };
      res.on("finish", end);
      res.on("close", end);
      if (stopping && !res.headersSent) res.setHeader("Connection", "close");
    });
  }

  function track(promise) {
    if (!promise || typeof promise.then !== "function") return promise;
    tasks.add(promise);
    const forget = () => tasks.delete(promise);
    promise.then(forget, forget);
    return promise;
  }

  function begin(signal) {
    if (stopping) {
      log(`[shutdown] second ${signal}: exiting now`);
      exit(0);
      return;
    }
    stopping = true;
    const started = Date.now();
    log(
      `[shutdown] ${signal}: finishing ${active} request(s) and ${tasks.size} task(s) before exit (max ${maxWaitMs}ms)`,
    );
    const tick = () => {
      const waited = Date.now() - started;
      if ((active === 0 && tasks.size === 0) || waited >= maxWaitMs) {
        log(
          `[shutdown] exit after ${waited}ms (requests left ${active}, tasks left ${tasks.size})`,
        );
        exit(0);
        return;
      }
      setTimeout(tick, pollMs);
    };
    tick();
  }

  return {
    begin,
    track,
    isStopping: () => stopping,
    get active() {
      return active;
    },
    get pending() {
      return tasks.size;
    },
  };
}

function installGracefulShutdown(opts) {
  const shutdown = createGracefulShutdown(opts);
  process.on("SIGTERM", () => shutdown.begin("SIGTERM"));
  process.on("SIGINT", () => shutdown.begin("SIGINT"));
  return shutdown;
}

module.exports = { createGracefulShutdown, installGracefulShutdown };
