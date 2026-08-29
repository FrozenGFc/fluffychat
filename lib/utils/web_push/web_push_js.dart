// FrozenGFc #V99: the web half of the Web Push facade.
//
// Deliberately thin. All of the real browser work lives in web/push_client.js,
// which is plain JavaScript; this file only calls those four functions. Keeping
// the interop surface this small is what makes the feature reviewable.
import 'dart:js_interop';
// `has` on globalContext lives in the unsafe library; it is the only thing used
// from it, and only to check that push_client.js actually loaded.
import 'dart:js_interop_unsafe';

@JS('fcPushPermission')
external JSString _permission();

@JS('fcPushExisting')
external JSPromise<JSString> _existing();

@JS('fcPushSubscribe')
external JSPromise<JSString> _subscribe(JSString vapidKey);

@JS('fcPushUnsubscribe')
external JSPromise<JSString> _unsubscribe();

/// Guards against push_client.js being absent (an old cached index.html, or a
/// browser that blocked the script): calling a missing global would otherwise
/// throw something unhelpful.
bool get _ready => globalContext.has('fcPushPermission');

String permission() => _ready ? _permission().toDart : 'unsupported';

Future<String> existing() async {
  if (!_ready) return '';
  return (await _existing().toDart).toDart;
}

Future<String> subscribe(String vapidKey) async {
  if (!_ready) throw UnsupportedError('push_client.js did not load');
  return (await _subscribe(vapidKey.toJS).toDart).toDart;
}

Future<String> unsubscribe() async {
  if (!_ready) return '';
  return (await _unsubscribe().toDart).toDart;
}
