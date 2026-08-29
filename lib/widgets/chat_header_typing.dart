// FrozenGFc #V91: the "печатает…" line in the chat header.
//
// WhatsApp puts typing where the online status goes, not in the timeline. This
// widget shows the typing text when somebody is typing and otherwise renders
// [fallback] — which is upstream's own presence / participant-count subtitle,
// passed in untouched so an upstream bump cannot collide with us.
//
// ⚠ TYPING IS AN EPHEMERAL EVENT: it does not rebuild the timeline and it does
// NOT come through onSyncStatus, which is what the surrounding StreamBuilder
// listens to. Without the stream filter below the header would simply never
// update — the same trap #V82 hit with read receipts.

import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/utils/room_status_extension.dart';

class ChatHeaderTyping extends StatelessWidget {
  final Room room;
  final TextStyle style;
  final Widget fallback;

  const ChatHeaderTyping({
    required this.room,
    required this.style,
    required this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<Object>(
      stream: room.client.onSync.stream.where(
        (syncUpdate) =>
            syncUpdate.rooms?.join?[room.id]?.ephemeral?.any(
              (ephemeral) => ephemeral.type == 'm.typing',
            ) ??
            false,
      ),
      builder: (context, _) {
        // getLocalizedTypingText() is upstream's own helper: it drops our own
        // user, handles one / two / many typists and the direct-versus-group
        // wording, and returns '' when nobody is typing.
        final text = room.getLocalizedTypingText(context);
        if (text.isEmpty) return fallback;
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // The accent colour, so it reads as activity rather than as metadata.
          style: style.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
