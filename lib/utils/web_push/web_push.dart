// FrozenGFc #V99: Web Push, the browser-only notification path.
//
// ⚠ THIS IS NOT background_push.dart AND MUST NOT BECOME IT. That file is the
// mobile path (FCM on Android, UnifiedPush on Linux) and it imports dart:io, so
// it cannot even be compiled for web. Nothing here touches it.
//
// The platform-specific half is chosen by conditional import, so a non-web
// build gets a stub that does nothing and pulls in no web libraries.
import 'dart:convert';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/platform_infos.dart';

import 'web_push_none.dart' if (dart.library.js_interop) 'web_push_js.dart'
    as impl;

abstract class WebPush {
  /// The VAPID public key. ⚠ It is NOT compiled into the fork: the default is
  /// empty and the real value is supplied at runtime from config.json, which
  /// lives only on our own server (the #V71/#V85 rule about keeping the public
  /// repository free of anything of ours). Empty key => the feature is hidden.
  static String get vapidKey => AppSettings.webPushVapidKey.value;

  /// Sygnal keys its pushkins by app id, and a web subscription is a completely
  /// different kind of pushkey from an FCM token, so it gets its own id. The
  /// ".web" suffix mirrors how the mobile path appends ".data_message".
  static String get appId => '${AppConfig.pushNotificationsAppId}.web';

  static bool get isAvailable =>
      PlatformInfos.isWeb && vapidKey.isNotEmpty && permission != 'unsupported';

  /// 'unsupported' | 'default' | 'granted' | 'denied'
  static String get permission => impl.permission();

  /// The opt-in path. ⚠ MUST be reached from a real user gesture — Safari
  /// refuses the permission prompt otherwise, and on iOS refuses it outright
  /// unless the app was added to the Home Screen.
  static Future<void> enable(Client client) async {
    final sub = await impl.subscribe(vapidKey);
    await _setPusher(client, sub);
  }

  /// Start-up path: never prompts. If the browser already holds a subscription
  /// we make sure Synapse still has a matching pusher for it — a pusher can be
  /// lost (logout, another session tidying up) while the browser subscription
  /// survives, and then notifications stop with nothing on screen to say so.
  static Future<void> refresh(Client client) async {
    if (!isAvailable || permission != 'granted') return;
    final sub = await impl.existing();
    if (sub.isEmpty) return;
    await _setPusher(client, sub);
  }

  static Future<void> disable(Client client) async {
    final sub = await impl.unsubscribe();
    if (sub.isEmpty) return;
    final map = _parse(sub);
    if (map == null) return;
    try {
      final pushers = await client.getPushers() ?? [];
      for (final p in pushers) {
        if (p.appId == appId && p.pushkey == map['p256dh']) {
          await client.deletePusher(p);
        }
      }
    } catch (e, s) {
      Logs().w('[WebPush] Unable to remove pusher', e, s);
    }
  }

  static Map<String, String>? _parse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final endpoint = j['endpoint'], p256dh = j['p256dh'], auth = j['auth'];
      if (endpoint is! String || p256dh is! String || auth is! String) {
        return null;
      }
      if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) return null;
      return {'endpoint': endpoint, 'p256dh': p256dh, 'auth': auth};
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setPusher(Client client, String raw) async {
    final map = _parse(raw);
    if (map == null) throw Exception('bad-subscription');
    if (!client.isLogged()) return;

    final gatewayUrl = AppSettings.pushNotificationsGatewayUrl.value;
    if (gatewayUrl.isEmpty) throw Exception('no-gateway');

    // ⚠ SHAPE DICTATED BY SYGNAL'S webpush PUSHKIN, not chosen by us:
    // pushkey is the p256dh, and the endpoint and auth travel in data.
    final pushers = await (client.getPushers().catchError((e) {
      Logs().w('[WebPush] Unable to list pushers', e);
      return <Pusher>[];
    })) ?? [];

    if (pushers.any(
      (p) =>
          p.appId == appId &&
          p.pushkey == map['p256dh'] &&
          p.kind == 'http' &&
          p.data.url.toString() == gatewayUrl &&
          p.data.additionalProperties['endpoint'] == map['endpoint'],
    )) {
      Logs().i('[WebPush] Pusher already registered');
      return;
    }

    // Drop OUR stale web pushers for this account. Scoped by appId so the
    // Android/FCM pushers (#V92/#V93) can never be touched by this.
    for (final p in pushers.where((p) => p.appId == appId)) {
      try {
        await client.deletePusher(p);
        Logs().i('[WebPush] Removed a stale web pusher');
      } catch (e, s) {
        Logs().w('[WebPush] Unable to remove a stale web pusher', e, s);
      }
    }

    await client.postPusher(
      Pusher(
        pushkey: map['p256dh']!,
        appId: appId,
        appDisplayName: PlatformInfos.appDisplayName,
        deviceDisplayName: client.deviceName ?? 'web',
        lang: 'en',
        kind: 'http',
        data: PusherData(
          url: Uri.parse(gatewayUrl),
          format: AppSettings.pushNotificationsPusherFormat.value,
          additionalProperties: {
            'endpoint': map['endpoint']!,
            'auth': map['auth']!,
          },
        ),
      ),
      append: true,
    );
    Logs().i('[WebPush] Pusher registered');
  }
}
