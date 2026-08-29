// FrozenGFc #V97: the group-call button.
//
// Group calls are NOT an in-app feature here. Our client cannot join a MatrixRTC
// call (#V95: the Dart SDK carries the signalling half only, there is no LiveKit
// media client, and it speaks com.famedly.call.* rather than m.call.member).
// What we can do is hand the room to Element Call, which we host ourselves, and
// let the browser do the media. This widget is that hand-off.
//
// ⚠ IT MUST LOOK LIKE IT LEAVES THE APP. Pretending to be an in-app call would
// be a lie the moment the browser opens, so the icon is the "open in new window"
// one and the confirmation says plainly where the user is going.

import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';

class GroupCallButton extends StatelessWidget {
  final Room room;

  const GroupCallButton({required this.room, super.key});

  /// The link Element Call itself would build for this room.
  ///
  /// ⚠ The room id lives in the FRAGMENT, after the `#`. Browsers never send a
  /// fragment to the server, so the room id never reaches our nginx logs — which
  /// is precisely why Element Call puts it there.
  ///
  /// ⚠ THE HOST IS DERIVED, NOT HARDCODED, and that is deliberate twice over.
  /// It keeps our domain in exactly ONE file (setting_keys.dart), which is what
  /// the push-time leak guard allows (#V85) — a second copy here would make the
  /// guard refuse the push, correctly. And it means that if the homeserver ever
  /// moves, this button follows it instead of silently pointing at the old host.
  static String urlFor(Room room) {
    // ⚠ r'/+$' — the $ must be the END-OF-STRING anchor. Written as r'/+\$' it
    // is a LITERAL dollar sign and trailing slashes are silently never stripped.
    final base = AppSettings.defaultHomeserver.value.replaceAll(RegExp(r'/+$'), '');
    return '$base/call/room#?roomId=${Uri.encodeComponent(room.id)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      // Not a telephone handset: this opens the browser, and the icon should
      // say so before the tap rather than after it.
      icon: const Icon(Icons.videocam_outlined),
      color: theme.colorScheme.primary,
      tooltip: 'Групповой звонок',
      onPressed: () async {
        final ok = await showOkCancelAlertDialog(
          context: context,
          title: 'Групповой звонок',
          // ⚠ ONE short line of honest limits, at the moment they matter —
          // #V96 measured the ceiling on this machine.
          message: 'Откроется в браузере. До 8 человек: голосом хорошо, '
              'с видео — примерно 4-5. Остальные заходят той же кнопкой '
              'из этого же чата.',
          okLabel: 'Открыть',
          cancelLabel: 'Отмена',
        );
        if (ok != OkCancelResult.ok) return;
        await launchUrlString(
          urlFor(room),
          // The browser, not an in-app view: we ship no webview on any
          // platform (#V95), and on web this becomes a new tab.
          mode: LaunchMode.externalApplication,
        );
      },
    );
  }
}
