'use strict';
// FrozenGFc #V99 — the browser half of Web Push, kept in plain JS on purpose.
//
// Dart could do this through dart:js_interop, but the fiddly parts (service
// worker registration, permission, PushManager, key encoding) are far easier to
// read, review and syntax-check here. Dart calls these four functions and does
// nothing else with the web push APIs.
//
// Every function is safe to call on a browser with no support at all.

(function () {
  var SW_URL = 'push_sw.js'; // relative -> resolves inside our own subpath

  function supported() {
    return (
      typeof navigator !== 'undefined' &&
      'serviceWorker' in navigator &&
      typeof window !== 'undefined' &&
      'PushManager' in window &&
      'Notification' in window
    );
  }

  function b64ToBytes(b64) {
    var pad = '='.repeat((4 - (b64.length % 4)) % 4);
    var raw = atob((b64 + pad).replace(/-/g, '+').replace(/_/g, '/'));
    var out = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }

  function triple(sub) {
    if (!sub) return '';
    var j = sub.toJSON();
    if (!j || !j.endpoint || !j.keys || !j.keys.p256dh || !j.keys.auth) return '';
    // The spec gives these already base64url-encoded, which is exactly the form
    // Sygnal's webpush pushkin wants (pushkey = p256dh, data.endpoint, data.auth).
    return JSON.stringify({
      endpoint: j.endpoint,
      p256dh: j.keys.p256dh,
      auth: j.keys.auth
    });
  }

  async function register() {
    return navigator.serviceWorker.register(SW_URL);
  }

  // 'unsupported' | 'default' | 'granted' | 'denied'
  window.fcPushPermission = function () {
    if (!supported()) return 'unsupported';
    return Notification.permission;
  };

  // Registers the worker and returns any EXISTING subscription, without ever
  // prompting. Used at start-up so a returning session re-registers its pusher.
  window.fcPushExisting = async function () {
    if (!supported()) return '';
    try {
      var reg = await register();
      await navigator.serviceWorker.ready;
      return triple(await reg.pushManager.getSubscription());
    } catch (e) {
      return '';
    }
  };

  // The opt-in path. MUST be called from a real user gesture: Safari refuses
  // Notification.requestPermission() otherwise, and on iOS it refuses entirely
  // unless the site has been added to the Home Screen.
  window.fcPushSubscribe = async function (vapidKey) {
    if (!supported()) throw new Error('unsupported');
    if (!vapidKey) throw new Error('no-vapid-key');

    var reg = await register();
    await navigator.serviceWorker.ready;

    var perm = await Notification.requestPermission();
    if (perm !== 'granted') throw new Error('permission-' + perm);

    var sub = await reg.pushManager.getSubscription();
    if (sub) {
      // ⚠ A subscription is bound to the applicationServerKey it was made with.
      // If our VAPID key was rotated, the old subscription is dead and silently
      // stays dead, so drop it and make a new one rather than reusing it.
      var want = b64ToBytes(vapidKey);
      var have = sub.options && sub.options.applicationServerKey
        ? new Uint8Array(sub.options.applicationServerKey)
        : null;
      var same = have && have.length === want.length;
      if (same) {
        for (var i = 0; i < want.length; i++) {
          if (have[i] !== want[i]) { same = false; break; }
        }
      }
      if (!same) {
        try { await sub.unsubscribe(); } catch (e) { /* keep going */ }
        sub = null;
      }
    }
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true, // required by Chrome, and by iOS
        applicationServerKey: b64ToBytes(vapidKey)
      });
    }
    var t = triple(sub);
    if (!t) throw new Error('bad-subscription');
    return t;
  };

  window.fcPushUnsubscribe = async function () {
    if (!supported()) return '';
    try {
      var reg = await navigator.serviceWorker.getRegistration(SW_URL);
      if (!reg) return '';
      var sub = await reg.pushManager.getSubscription();
      if (!sub) return '';
      var t = triple(sub);
      await sub.unsubscribe();
      return t;
    } catch (e) {
      return '';
    }
  };
})();
