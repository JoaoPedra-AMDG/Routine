'use strict';
const CACHE_NAME = __ROUTINE_CACHE_NAME__;
const RESOURCES = __ROUTINE_RESOURCES__;
const ROOT = new URL('./', self.registration.scope);
const resourceUrl = path => new URL(path, ROOT).href;

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    // Installation succeeds only when every app file is available offline.
    await cache.addAll(RESOURCES.map(path => new Request(resourceUrl(path), {cache: 'reload'})));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith('routine-offline-') && name !== CACHE_NAME) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== ROOT.origin || !url.pathname.startsWith(ROOT.pathname)) return;
  const path = url.pathname.slice(ROOT.pathname.length);
  const resource = event.request.mode === 'navigate' || path === '' ? 'index.html' : path;
  if (!RESOURCES.includes(resource)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const address = resourceUrl(resource);
    const saved = await cache.match(address);
    if (saved) return saved;
    const response = await fetch(new Request(address, {cache: 'reload'}));
    if (response.ok) await cache.put(address, response.clone());
    return response;
  })());
});

self.addEventListener('message', event => {
  if (event.data?.type !== 'routine-offline-status' || !event.ports[0]) return;
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    const stored = new Set((await cache.keys()).map(request => request.url));
    event.ports[0].postMessage({ready: RESOURCES.every(path => stored.has(resourceUrl(path)))});
  })());
});
