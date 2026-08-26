/* Kocia Tabliczka — service worker.
   Po zmianie plików podnieś numer wersji, żeby telefon pobrał nowe. */
const CACHE = 'kocia-tabliczka-v2';
const SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './config.js',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;

  // nie dotykamy wywołań do Supabase — muszą iść prosto do sieci
  const url = new URL(req.url);
  if (url.hostname.endsWith('supabase.co')) return;

  // config.js zawsze najpierw z sieci, żeby zmiana kluczy działała od razu
  if (url.pathname.endsWith('config.js')) {
    e.respondWith(fetch(req).catch(() => caches.match(req)));
    return;
  }

  // wejście do aplikacji: najpierw sieć, offline z pamięci
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).catch(() => caches.match('./index.html'))
    );
    return;
  }

  // reszta: z pamięci, a w tle dociągane świeże (także czcionki Google)
  e.respondWith(
    caches.match(req).then(hit => {
      const net = fetch(req).then(res => {
        if (res && (res.ok || res.type === 'opaque')) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy));
        }
        return res;
      }).catch(() => hit);
      return hit || net;
    })
  );
});
