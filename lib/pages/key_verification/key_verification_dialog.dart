// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:ui';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

class KeyVerificationDialog extends StatefulWidget {
  Future<bool?> show(BuildContext context) => showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => this,
    barrierDismissible: false,
  );

  final KeyVerification request;

  const KeyVerificationDialog({super.key, required this.request});

  @override
  KeyVerificationPageState createState() => KeyVerificationPageState();
}

class KeyVerificationPageState extends State<KeyVerificationDialog> {
  void Function()? originalOnUpdate;
  late final List<dynamic> sasEmoji;

  @override
  void initState() {
    originalOnUpdate = widget.request.onUpdate;
    widget.request.onUpdate = () {
      originalOnUpdate?.call();
      setState(() {});
    };
    widget.request.client.getProfileFromUserId(widget.request.userId).then((p) {
      profile = p;
      setState(() {});
    });
    rootBundle.loadString('assets/sas-emoji.json').then((e) {
      sasEmoji = json.decode(e);
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.request.onUpdate =
        originalOnUpdate; // don't want to get updates anymore
    if (![
      KeyVerificationState.error,
      KeyVerificationState.done,
    ].contains(widget.request.state)) {
      widget.request.cancel('m.user');
    }
    textEditingController?.dispose();
    super.dispose();
  }

  Profile? profile;

  Future<void> checkInput(String input) async {
    if (input.isEmpty) return;

    final valid = await showFutureLoadingDialog(
      context: context,
      future: () async {
        // make sure the loading spinner shows before we test the keys
        await Future.delayed(const Duration(milliseconds: 100));
        var valid = false;
        try {
          await widget.request.openSSSS(keyOrPassphrase: input);
          valid = true;
        } catch (_) {
          valid = false;
        }
        return valid;
      },
    );
    if (valid.error != null) {
      if (!mounted) return;
      await showOkAlertDialog(
        useRootNavigator: false,
        context: context,
        title: L10n.of(context).incorrectPassphraseOrKey,
      );
    }
  }

  TextEditingController? textEditingController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    User? user;
    final directChatId = widget.request.client.getDirectChatFromUserId(
      widget.request.userId,
    );
    if (directChatId != null) {
      user = widget.request.client
          .getRoomById(directChatId)!
          .unsafeGetUserFromMemoryOrFallback(widget.request.userId);
    }
    final displayName =
        user?.calcDisplayname() ?? widget.request.userId.localpart!;
    var title = Text(L10n.of(context).verifyTitle);
    Widget body;
    final buttons = <Widget>[];

    switch (widget.request.state) {
      case KeyVerificationState.showQRSuccess:
      case KeyVerificationState.confirmQRScan:
        throw 'Not implemented';
      case KeyVerificationState.askSSSS:
        // prompt the user for their ssss passphrase / key
        textEditingController = TextEditingController();
        String input;
        body = Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisSize: .min,
            children: <Widget>[
              Text(
                L10n.of(context).askSSSSSign,
                style: const TextStyle(fontSize: 20),
              ),
              Container(height: 10),
              TextField(
                controller: textEditingController,
                autofocus: false,
                autocorrect: false,
                onSubmitted: (s) {
                  input = s;
                  checkInput(input);
                },
                minLines: 1,
                maxLines: 1,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: L10n.of(context).passphraseOrKey,
                  prefixStyle: TextStyle(color: theme.colorScheme.primary),
                  suffixStyle: TextStyle(color: theme.colorScheme.primary),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            child: Text(L10n.of(context).submit),
            onPressed: () => checkInput(textEditingController!.text),
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            child: Text(L10n.of(context).skip),
            onPressed: () => widget.request.openSSSS(skip: true),
          ),
        );
        break;
      case KeyVerificationState.askAccept:
        title = Text(L10n.of(context).newVerificationRequest);
        body = Column(
          mainAxisSize: .min,
          children: [
            const SizedBox(height: 16),
            Avatar(
              mxContent: user?.avatarUrl,
              name: displayName,
              size: Avatar.defaultSize * 2,
            ),
            const SizedBox(height: 16),
            Text(L10n.of(context).askVerificationRequest(displayName)),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: () => widget.request.rejectVerification().then((_) {
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: false).pop(false);
            }),
            child: Text(
              L10n.of(context).reject,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: () => widget.request.acceptVerification(),
            child: Text(L10n.of(context).accept),
          ),
        );
        break;
      case KeyVerificationState.askChoice:
      case KeyVerificationState.waitingAccept:
        body = Center(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  Avatar(mxContent: user?.avatarUrl, name: displayName),
                  const SizedBox(
                    width: Avatar.defaultSize + 2,
                    height: Avatar.defaultSize + 2,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                L10n.of(context).waitingPartnerAcceptRequest,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: () => widget.request.cancel(),
            child: Text(L10n.of(context).cancel),
          ),
        );

        break;
      case KeyVerificationState.askSas:
        // FrozenGFc #V102: show BOTH forms of the SAS at once — the emoji AND
        // the decimal code — with ONE pair of buttons.
        //
        // ⚠ WHY BOTH, AND WHY IT IS NOT WEAKER (from matrix 8.1.0's source):
        // sasNumbers is _bytesToInt(makeSas(5), 13) and sasEmojis is
        // _bytesToInt(makeSas(6), 6); makeSas(n) is generateBytes(sasInfo, n),
        // the first n bytes of ONE HKDF stream over a fixed info string. So the
        // two are encodings of the SAME secret — decimal reads the first 39
        // bits, emoji the first 42. The emoji bits are a strict superset of the
        // decimal bits, so confirming either is a full comparison of the
        // negotiated SAS and neither is truncated.
        //
        // ⚠ WHY IT EXISTS: Element renders emoji even when only `decimal` was
        // negotiated (measured in #V76). A screen that offered digits alone
        // could not be satisfied against Element at all — the user's only
        // working button was Cancel. Both sides of this screen are labelled so
        // it is obvious which half matches what the other device is showing.
        final sasNumbers = widget.request.sasNumbers;
        final sasDigits = sasNumbers
            .map((n) => n.toString().padLeft(4, '0'))
            .join('  ');
        final showEmoji = widget.request.sasEmojis.isNotEmpty;

        title = Text(
          L10n.of(context).compareEmojiMatch,
          maxLines: 1,
          style: const TextStyle(fontSize: 16),
        );
        body = Column(
          mainAxisSize: .min,
          children: <Widget>[
            const SizedBox(height: 4),
            const Text(
              'Достаточно, чтобы совпало ОДНО из двух — смотрите на то, '
              'что показывает второе устройство.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            if (showEmoji) ...[
              const SizedBox(height: 14),
              Text(
                'ЭМОДЖИ — если на втором устройстве Element',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              // upstream's exact rendering, so the layout is unchanged
              Text.rich(
                TextSpan(
                  children: widget.request.sasEmojis
                      .map((e) => WidgetSpan(child: _Emoji(e, sasEmoji)))
                      .toList(),
                ),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 8),
            ],
            const SizedBox(height: 10),
            Text(
              'ЦИФРЫ — если на втором устройстве тоже «Мессенджер»',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              sasDigits,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 2),
            ),
            const SizedBox(height: 6),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: () => widget.request.rejectSas(),
            child: Text(
              L10n.of(context).theyDontMatch,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            onPressed: () => widget.request.acceptSas(),
            child: Text(L10n.of(context).theyMatch),
          ),
        );
        break;
      case KeyVerificationState.waitingSas:
        final acceptText = widget.request.sasTypes.contains('emoji')
            ? L10n.of(context).waitingPartnerEmoji
            : L10n.of(context).waitingPartnerNumbers;
        body = Column(
          mainAxisSize: .min,
          children: <Widget>[
            const SizedBox(height: 16),
            const CircularProgressIndicator.adaptive(strokeWidth: 2),
            const SizedBox(height: 16),
            Text(acceptText, textAlign: TextAlign.center),
          ],
        );
        break;
      case KeyVerificationState.done:
        title = Text(L10n.of(context).verifySuccess);
        body = const Padding(
          padding: EdgeInsets.all(16.0),
          child: Icon(
            Icons.verified_outlined,
            color: Colors.green,
            size: 128.0,
          ),
        );
        buttons.add(
          AdaptiveDialogAction(
            child: Text(L10n.of(context).close),
            onPressed: () =>
                Navigator.of(context, rootNavigator: false).pop(true),
          ),
        );
        break;
      case KeyVerificationState.error:
        title = const Text('');
        body = Column(
          mainAxisSize: .min,
          children: <Widget>[
            const SizedBox(height: 16),
            Icon(Icons.cancel, color: theme.colorScheme.error, size: 64.0),
            const SizedBox(height: 16),
            // TODO: Add better error UI to user
            Text(
              'Error ${widget.request.canceledCode}: ${widget.request.canceledReason}',
              textAlign: TextAlign.center,
            ),
          ],
        );
        buttons.add(
          AdaptiveDialogAction(
            child: Text(L10n.of(context).close),
            onPressed: () =>
                Navigator.of(context, rootNavigator: false).pop(false),
          ),
        );
        break;
    }

    return AlertDialog.adaptive(
      title: title,
      content: SizedBox(
        height: 256,
        width: 256,
        child: ListView(children: [body]),
      ),
      actions: buttons,
    );
  }
}

class _Emoji extends StatelessWidget {
  final KeyVerificationEmoji emoji;
  final List<dynamic>? sasEmoji;

  const _Emoji(this.emoji, this.sasEmoji);

  String getLocalizedName() {
    final sasEmoji = this.sasEmoji;
    if (sasEmoji == null) {
      // asset is still being loaded
      return emoji.name;
    }
    final translations = Map<String, String?>.from(
      sasEmoji[emoji.number]['translated_descriptions'],
    );
    translations['en'] = emoji.name;
    for (final locale in PlatformDispatcher.instance.locales) {
      final wantLocaleParts = locale.toString().split('_');
      final wantLanguage = wantLocaleParts.removeAt(0);
      for (final haveLocale in translations.keys) {
        final haveLocaleParts = haveLocale.split('_');
        final haveLanguage = haveLocaleParts.removeAt(0);
        if (haveLanguage == wantLanguage &&
            (Set.from(haveLocaleParts)..removeAll(wantLocaleParts)).isEmpty &&
            (translations[haveLocale]?.isNotEmpty ?? false)) {
          return translations[haveLocale]!;
        }
      }
    }
    return emoji.name;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: <Widget>[
        Text(emoji.emoji, style: const TextStyle(fontSize: 50)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(getLocalizedName()),
        ),
        const SizedBox(height: 10, width: 5),
      ],
    );
  }
}
