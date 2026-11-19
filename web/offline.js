// Service-worker integration only. App screens and state stay in Flutter.
(() => {
  let preparation;

  const activated = worker => new Promise(resolve => {
    if (worker.state === 'activated') return resolve(true);
    if (worker.state === 'redundant') return resolve(false);
    const timeout = setTimeout(() => finish(false), 120000);
    const changed = () => {
      if (worker.state === 'activated') finish(true);
      if (worker.state === 'redundant') finish(false);
    };
    const finish = ready => {
      clearTimeout(timeout);
      worker.removeEventListener('statechange', changed);
      resolve(ready);
    };
    worker.addEventListener('statechange', changed);
  });

  const cached = worker => new Promise(resolve => {
    const channel = new MessageChannel();
    const finish = ready => {
      clearTimeout(timeout);
      channel.port1.close();
      resolve(ready);
    };
    const timeout = setTimeout(() => finish(false), 3000);
    channel.port1.onmessage = event => finish(event.data?.ready === true);
    try {
      worker.postMessage({type: 'routine-offline-status'}, [channel.port2]);
    } catch {
      finish(false);
    }
  });

  async function prepare() {
    if (!navigator.serviceWorker) return false;
    const scope = new URL('./', document.baseURI).href;
    let registration;
    try {
      registration = await navigator.serviceWorker.register(
        new URL('flutter_service_worker.js', scope).href,
        {scope, updateViaCache: 'none'},
      );
    } catch {
      // Offline launches use the worker already installed on this device.
      registration = await navigator.serviceWorker.getRegistration(scope);
    }
    if (!registration) return false;
    const worker = registration.installing || registration.waiting || registration.active;
    if (worker && await activated(worker) && await cached(worker)) return true;
    return registration.active ? cached(registration.active) : false;
  }

  window.prepareRoutineOffline = (retry = false) => {
    if (!preparation || retry) preparation = prepare().catch(() => false);
    return preparation;
  };
})();
