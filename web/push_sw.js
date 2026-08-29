'use strict';
// FrozenGFc #V99 — Web Push service worker for «Мессенджер».
//
// ⚠⚠ THIS FILE MUST NEVER GAIN A fetch HANDLER.
// The app is a Flutter web build whose filenames are NOT content-hashed
// (main.dart.js and ~120 .part.js chunks are overwritten in place on every
// deploy), so anything that caches responses here would eventually serve a
// mixture of old and new chunks — a stale build that is very hard to diagnose.
// With no fetch handler the browser does not route requests through this
// worker at all, so it cannot serve anything. Keep it that way.
//
// Its whole job: show a notification when a push arrives, and focus/open the
// app when that notification is tapped.

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

// ⚠ iOS requires userVisibleOnly subscriptions, which means EVERY push must
// result in a visible notification. If we ever silently swallowed one, Safari
// could revoke the subscription. So this handler always shows something, even
// when the payload is missing or unparseable.
self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {};
  }

  // ⚠ There is deliberately no message text here. We register the pusher with
  // format event_id_only, so Synapse sends room_id / event_id / counts and no
  // content at all; and this worker could not decrypt an encrypted event even
  // if it had one. Do not try to make this cleverer.
  var unread = Number(data.unread || 0);
  var body = 'Новое сообщение';
  if (unread > 1) body = 'Новых сообщений: ' + unread;

  event.waitUntil(
    self.registration.showNotification('Мессенджер', {
      body: body,
      icon: 'icons/Icon-apple-180.png',
      badge: 'icons/Icon-apple-120.png',
      // Collapse repeats from the same room instead of stacking them.
      tag: data.room_id || 'fc-message',
      renotify: true,
      data: { room_id: data.room_id || null }
    })
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var roomId = (event.notification.data && event.notification.data.room_id) || null;
  var base = new URL('./', self.registration.scope).href;

  event.waitUntil(
    (async function () {
      var all = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true
      });
      // ⚠ If the app is already open, FOCUS it and stop. We deliberately do NOT
      // call client.navigate() to deep-link into the room: this app uses hash
      // routing, navigate() performs a real navigation, and that would reload
      // the whole ~11 MB Flutter bundle just because a notification was tapped.
      for (var i = 0; i < all.length; i++) {
        if (all[i].url.indexOf(base) === 0) {
          return all[i].focus();
        }
      }
      // Nothing open: a cold start is a full load anyway, so it is free to land
      // directly in the room when we know which one it was.
      var url = roomId ? base + '#/rooms/' + encodeURIComponent(roomId) : base;
      return self.clients.openWindow(url);
    })()
  );
});
