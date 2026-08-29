// FrozenGFc #V99: the non-web half of the Web Push facade.
//
// Chosen by conditional import on every platform that is NOT web, so an Android
// or Windows build never sees a browser API. Everything is inert.

String permission() => 'unsupported';

Future<String> existing() async => '';

Future<String> subscribe(String vapidKey) async =>
    throw UnsupportedError('Web Push is only available in the browser');

Future<String> unsubscribe() async => '';
