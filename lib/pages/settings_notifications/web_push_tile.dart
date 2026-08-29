// FrozenGFc #V99: the browser-notification opt-in, in Settings ▸ Notifications.
//
// ⚠ IT IS A TILE YOU TAP, NOT A SWITCH THAT RESTORES STATE. Browser notification
// permission cannot be revoked by a page — only the user can, in the browser's
// own settings — so a switch that flipped back off would be lying about what it
// can do. Tapping asks; the tile then reports what actually happened.
//
// ⚠ THE TAP MATTERS. Safari only allows Notification.requestPermission() from a
// user gesture, and on iOS only when the site has been added to the Home
// Screen. That is why this cannot be done automatically at start-up.
import 'package:flutter/material.dart';

import 'package:fluffychat/utils/web_push/web_push.dart';
import 'package:fluffychat/widgets/matrix.dart';

class WebPushTile extends StatefulWidget {
  const WebPushTile({super.key});

  @override
  State<WebPushTile> createState() => _WebPushTileState();
}

class _WebPushTileState extends State<WebPushTile> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    String? error;
    try {
      await WebPush.enable(Matrix.of(context).client);
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Уведомления включены'
              : error.contains('permission-denied')
              ? 'Браузер запретил уведомления. Разрешите их для этого сайта в настройках браузера.'
              : 'Не удалось включить уведомления',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hidden entirely when there is no VAPID key configured or the browser has
    // no Push API, rather than offering a control that cannot work.
    if (!WebPush.isAvailable) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final permission = WebPush.permission;

    if (permission == 'granted') {
      return ListTile(
        leading: Icon(Icons.notifications_active_outlined,
            color: theme.colorScheme.primary),
        title: const Text('Уведомления в браузере'),
        subtitle: const Text(
          'Включены. Приходят, даже когда приложение закрыто. '
          'Текст сообщения в уведомлении не показывается.',
        ),
        trailing: Icon(Icons.check_circle, color: theme.colorScheme.primary),
      );
    }

    if (permission == 'denied') {
      return ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: const Text('Уведомления в браузере'),
        subtitle: const Text(
          'Запрещены в настройках браузера. Разрешите уведомления для этого '
          'сайта, затем вернитесь сюда.',
        ),
      );
    }

    return ListTile(
      leading: const Icon(Icons.notifications_outlined),
      title: const Text('Уведомления в браузере'),
      subtitle: const Text(
        'Получать уведомления, когда приложение закрыто. '
        'На iPhone сначала добавьте приложение на экран «Домой».',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_outlined),
      onTap: _busy ? null : _enable,
    );
  }
}
