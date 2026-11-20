function createKeyedQueue({ maxPending = 50 } = {}) {
  const tails = new Map();
  const pending = new Map();

  function run(key, fn) {
    const k = String(key);
    const waiting = pending.get(k) || 0;
    if (waiting >= maxPending) {
      const err = new Error("queue full");
      err.code = "QUEUE_FULL";
      return Promise.reject(err);
    }
    pending.set(k, waiting + 1);
    const prev = tails.get(k) || Promise.resolve();
    const result = prev.then(() => fn());
    const tail = result.then(
      () => {},
      () => {},
    );
    tails.set(k, tail);
    tail.then(() => {
      const left = (pending.get(k) || 1) - 1;
      if (left > 0) {
        pending.set(k, left);
        return;
      }
      pending.delete(k);
      if (tails.get(k) === tail) tails.delete(k);
    });
    return result;
  }

  return {
    run: run,
    size: () => pending.size,
    pendingFor: (key) => pending.get(String(key)) || 0,
  };
}

module.exports = { createKeyedQueue: createKeyedQueue };
