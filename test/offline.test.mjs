import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {basename, dirname, resolve, sep} from 'node:path';
import vm from 'node:vm';
import test from 'node:test';
import {buildOffline} from '../tool/build_offline.mjs';

const scope = 'https://example.test/Routine/';
const required = ['index.html', 'main.dart.js', 'flutter_bootstrap.js', 'install.js', 'offline.js',
  'assets/FontManifest.json', 'assets/assets/fonts/Roboto-Regular.ttf',
  'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js', 'canvaskit/chromium/canvaskit.wasm'];

function release(t) {
  const root = mkdtempSync(resolve(tmpdir(), 'routine-offline-tests-'));
  t.after(() => {
    assert(root.startsWith(resolve(tmpdir()) + sep));
    assert(basename(root).startsWith('routine-offline-tests-'));
    rmSync(root, {recursive: true, force: true});
  });
  for (const path of [...required, 'canvaskit/canvaskit.js.symbols']) {
    mkdirSync(dirname(resolve(root, path)), {recursive: true});
    writeFileSync(resolve(root, path), 'release:' + path);
  }
  return {root, ...buildOffline(root)};
}

function workerHost(source, sharedCaches = new Map()) {
  const handlers = new Map();
  let network = true, requested = 0, skipWaiting = false, claimed = false;
  const address = value => typeof value === 'string' ? value : value.url;
  const fetch = async request => {
    requested++;
    if (!network) throw new Error('No network');
    return new Response('cached:' + address(request));
  };
  const caches = {
    async open(name) {
      if (!sharedCaches.has(name)) sharedCaches.set(name, new Map());
      const entries = sharedCaches.get(name);
      return {
        async addAll(requests) {
          const responses = await Promise.all(requests.map(fetch));
          requests.forEach((request, i) => entries.set(address(request), responses[i]));
        },
        async keys() {return [...entries.keys()].map(url => new Request(url));},
        async match(request) {return entries.get(address(request))?.clone();},
        async put(request, response) {entries.set(address(request), response);},
      };
    },
    async keys() {return [...sharedCaches.keys()];},
    async delete(name) {return sharedCaches.delete(name);},
  };
  vm.runInNewContext(source, {URL, Request, caches, fetch, self: {
    registration: {scope},
    addEventListener: (type, handler) => handlers.set(type, handler),
    async skipWaiting() {skipWaiting = true;},
    clients: {async claim() {claimed = true;}},
  }});
  async function dispatch(type, fields = {}) {
    const pending = [];
    let response;
    handlers.get(type)({...fields, waitUntil: promise => pending.push(promise), respondWith: promise => {response = promise;}});
    await Promise.all(pending);
    return response;
  }
  return {dispatch, caches: sharedCaches,
    offline() {network = false;},
    get requests() {return requested;},
    get skipped() {return skipWaiting;},
    get claimed() {return claimed;},
  };
}

test('full package reopens under /Routine/ with no network, including fonts and both renderers', async t => {
  const releaseFiles = release(t);
  assert(!releaseFiles.paths.some(path => path.endsWith('.symbols')));
  const host = workerHost(releaseFiles.worker);
  await host.dispatch('install');
  await host.dispatch('activate');
  assert(host.skipped && host.claimed);
  host.offline();
  const downloads = host.requests;
  for (const path of ['', ...required, 'main.dart.js?v=cache-buster']) {
    const response = await host.dispatch('fetch', {request: new Request(scope + path)});
    assert.equal(response.status, 200);
    assert((await response.text()).startsWith('cached:' + scope));
  }
  const deepLink = await host.dispatch('fetch', {request: {method: 'GET', mode: 'navigate', url: scope + 'a/day'}});
  assert.equal(await deepLink.text(), 'cached:' + scope + 'index.html');
  assert.equal(host.requests, downloads, 'offline launches must not need a network request');
  assert.equal(await host.dispatch('fetch', {request: new Request('https://example.test/Other/main.dart.js')}), undefined);
  let ready;
  await host.dispatch('message', {data: {type: 'routine-offline-status'}, ports: [{postMessage: message => {ready = message.ready;}}]});
  assert.equal(ready, true);
  host.caches.get(releaseFiles.name).delete(scope + 'canvaskit/canvaskit.wasm');
  await host.dispatch('message', {data: {type: 'routine-offline-status'}, ports: [{postMessage: message => {ready = message.ready;}}]});
  assert.equal(ready, false, 'installation readiness requires the complete package');
});

test('failed updates retain the working version; successful updates replace only Routine caches', async t => {
  const original = release(t);
  const first = workerHost(original.worker);
  await first.dispatch('install');
  await first.dispatch('activate');
  writeFileSync(resolve(original.root, 'main.dart.js'), 'updated code');
  const next = buildOffline(original.root);
  assert.notEqual(next.name, original.name);
  assert.equal(buildOffline(original.root).name, next.name, 'worker generation is repeatable');
  const failed = workerHost(next.worker, first.caches);
  failed.offline();
  await assert.rejects(failed.dispatch('install'), /No network/);
  assert.equal(failed.skipped, false);
  assert(first.caches.has(original.name));
  first.offline();
  assert.equal((await first.dispatch('fetch', {request: new Request(scope)})).status, 200);
  first.caches.set('another-app-cache', new Map());
  const update = workerHost(next.worker, first.caches);
  await update.dispatch('install');
  await update.dispatch('activate');
  assert(!first.caches.has(original.name));
  assert(first.caches.has(next.name));
  assert(first.caches.has('another-app-cache'));
});

const integration = readFileSync(new URL('../web/offline.js', import.meta.url), 'utf8');
function shell(serviceWorker) {
  const window = {};
  class MessageChannel {
    constructor() {
      this.port1 = {close() {}};
      this.port2 = {postMessage: data => queueMicrotask(() => this.port1.onmessage({data}))};
    }
  }
  vm.runInNewContext(integration, {window, navigator: {serviceWorker}, document: {baseURI: scope},
    URL, MessageChannel, setTimeout, clearTimeout});
  return window;
}
const active = {state: 'activated', postMessage(message, ports) {ports[0].postMessage({ready: true});}};

test('offline readiness uses an existing worker if registration cannot connect', async () => {
  let calls = 0;
  const window = shell({
    async register() {calls++; throw new Error('Offline');},
    async getRegistration(url) {assert.equal(url, scope); return {active};},
  });
  assert.equal(await window.prepareRoutineOffline(), true);
  assert.equal(await window.prepareRoutineOffline(), true);
  assert.equal(calls, 1);
  assert.equal(await window.prepareRoutineOffline(true), true);
  assert.equal(calls, 2);
  assert.equal(await shell(undefined).prepareRoutineOffline(), false);
});

test('offline readiness waits for complete activation before enabling installation', async () => {
  let stateChanged;
  const installing = {state: 'installing',
    addEventListener(type, fn) {stateChanged = fn;},
    removeEventListener() {},
    postMessage: active.postMessage,
  };
  const window = shell({async register(url, options) {
    assert.equal(url, scope + 'flutter_service_worker.js');
    assert.equal(options.scope, scope);
    assert.equal(options.updateViaCache, 'none');
    return {installing};
  }});
  let ready = false;
  const preparation = window.prepareRoutineOffline().then(value => {ready = value;});
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(ready, false);
  installing.state = 'activated';
  stateChanged();
  await preparation;
  assert.equal(ready, true);
});
