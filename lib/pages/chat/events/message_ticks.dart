// FrozenGFc #V82: delivery ticks. See patches/v82_ticks.py for the reasoning,
// in particular why there is no "delivered" state.
import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/themes.dart';

enum MessageTickState { sending, sent, read, failed }

/// Works out what we can HONESTLY say about one of our own messages.
///
/// Matrix gives us: whether the server took the event, and whether other people
/// have published a read receipt covering it. There is no delivery receipt, so
/// there is no "delivered" state here on purpose.
MessageTickState messageTickState(Event event, Timeline? timeline) {
  if (event.status == EventStatus.error) return MessageTickState.failed;
  if (event.status == EventStatus.sending) return MessageTickState.sending;

  final room = event.room;
  final myId = room.client.userID;

  // Everyone else who is actually in the room.
  final others = room
      .getParticipants([Membership.join])
      .where((u) => u.id != myId)
      .map((u) => u.id)
      .toSet();
  if (others.isEmpty) return MessageTickState.sent;

  // Position of an event in the loaded timeline; -1 when it is not loaded.
  int posOf(String id) =>
      timeline?.events.indexWhere((e) => e.eventId == id) ?? -1;
  // The timeline is newest-first, so a SMALLER index means a NEWER event.
  final ourPos = posOf(event.eventId);

  for (final userId in others) {
    final r = room.receiptState.global.otherUsers[userId] ??
        room.receiptState.mainThread?.otherUsers[userId];
    if (r == null) return MessageTickState.sent;      // no receipt from them yet

    final theirPos = posOf(r.eventId);
    if (ourPos >= 0 && theirPos >= 0) {
      // Both loaded: their read event must be this one or newer.
      if (theirPos > ourPos) return MessageTickState.sent;
    } else {
      // Fall back to time when we cannot place the event in the timeline.
      if (r.ts < event.originServerTs.millisecondsSinceEpoch) {
        return MessageTickState.sent;
      }
    }
  }
  return MessageTickState.read;
}

/// The little tick row shown after the timestamp on our own messages.
class MessageTicks extends StatelessWidget {
  final Event event;
  final Timeline? timeline;

  const MessageTicks(this.event, this.timeline, {super.key});

  @override
  Widget build(BuildContext context) {
    // ⚠ A read receipt is an EPHEMERAL event: it does not rebuild the timeline,
    // so a plain widget here would keep showing "sent" for ever even though the
    // receipt had arrived (measured — the tick stayed at one check while the
    // app's own "seen by" avatar already showed the reader). Rebuild on the
    // same signal seen_by_row.dart uses: sync updates carrying m.receipt.
    return StreamBuilder(
      stream: event.room.client.onSync.stream.where(
        (syncUpdate) =>
            syncUpdate.rooms?.join?[event.room.id]?.ephemeral?.any(
              (ephemeral) => ephemeral.type == 'm.receipt',
            ) ??
            false,
      ),
      builder: (context, _) => _icon(context),
    );
  }

  Widget _icon(BuildContext context) {
    final theme = Theme.of(context);
    final state = messageTickState(event, timeline);

    final (IconData icon, Color color, String label) = switch (state) {
      MessageTickState.failed => (
          Icons.error_outline,
          theme.colorScheme.error,
          'не отправлено',
        ),
      MessageTickState.sending => (
          Icons.schedule,
          theme.chatMetaColor,
          'отправляется',
        ),
      MessageTickState.sent => (
          Icons.check,
          theme.chatMetaColor,
          'отправлено',
        ),
      MessageTickState.read => (
          Icons.done_all,
          theme.chatTickReadColor,
          'прочитано',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(left: 3.0),
      child: Semantics(
        label: label,
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
