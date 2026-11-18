self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  const title = payload.title || 'تذكير بالأذكار';
  const options = {
    body: payload.body || '',
    icon: new URL('../icons/Icon-192.png', self.registration.scope).href,
    badge: new URL('../icons/Icon-192.png', self.registration.scope).href,
    tag: payload.tag || 'al-atheer-azkar',
    silent: payload.soundEnabled === false,
    data: { url: payload.url || '/' },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(
    event.notification.data.url || '../',
    self.registration.scope,
  );
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow(target.href);
    }),
  );
});
