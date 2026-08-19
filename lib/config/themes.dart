// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class FluffyThemes {
  static const double columnWidth = 380.0;

  static const double maxTimelineWidth = columnWidth * 2;

  static const double navRailWidth = 80.0;

  static bool isColumnModeByWidth(double width) =>
      width > columnWidth * 2 + navRailWidth;

  static bool isColumnMode(BuildContext context) =>
      isColumnModeByWidth(MediaQuery.sizeOf(context).width);

  static bool isThreeColumnMode(BuildContext context) =>
      MediaQuery.sizeOf(context).width > FluffyThemes.columnWidth * 3.5;

  static LinearGradient backgroundGradient(BuildContext context, int alpha) {
    final colorScheme = Theme.of(context).colorScheme;
    return LinearGradient(
      begin: Alignment.topCenter,
      colors: [
        colorScheme.primaryContainer.withAlpha(alpha),
        colorScheme.secondaryContainer.withAlpha(alpha),
        colorScheme.tertiaryContainer.withAlpha(alpha),
        colorScheme.primaryContainer.withAlpha(alpha),
      ],
    );
  }

  static const Duration animationDuration = Duration(milliseconds: 250);
  static const Curve animationCurve = Curves.easeInOut;

  static ThemeData buildTheme(
    BuildContext context,
    Brightness brightness, [
    Color? seed,
  ]) {
    final colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: seed ?? Color(AppSettings.colorSchemeSeedInt.value),
      dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
    );
    final isColumnMode = FluffyThemes.isColumnMode(context);
    final dividerColor = brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainer;
    return ThemeData(
      visualDensity: VisualDensity.standard,
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      dividerColor: dividerColor,
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          iconColor: colorScheme.onSurface,
          disabledIconColor: colorScheme.onSurface,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: colorScheme.onSurface.withAlpha(128),
        selectionHandleColor: colorScheme.secondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: colorScheme.surfaceContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: isColumnMode ? 72 : 56,
        surfaceTintColor: isColumnMode ? colorScheme.surface : null,
        backgroundColor: isColumnMode ? colorScheme.surface : null,
        actionsPadding: isColumnMode
            ? const EdgeInsets.symmetric(horizontal: 16.0)
            : null,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness.reversed,
          statusBarBrightness: brightness,
          systemNavigationBarIconBrightness: brightness.reversed,
          systemNavigationBarColor: colorScheme.surface,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(width: 1, color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colorScheme.primary),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        strokeCap: StrokeCap.round,
        color: colorScheme.primary,
        refreshBackgroundColor: colorScheme.primaryContainer,
      ),
      snackBarTheme: isColumnMode
          ? const SnackBarThemeData(
              showCloseIcon: true,
              behavior: SnackBarBehavior.floating,
              width: FluffyThemes.columnWidth * 1.5,
            )
          : const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          elevation: 0,
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

extension on Brightness {
  Brightness get reversed =>
      this == Brightness.dark ? Brightness.light : Brightness.dark;
}

extension BubbleColorTheme on ThemeData {
  // ⚠ FrozenGFc #V80: THIS EXTENSION IS THE WHOLE CHAT PALETTE. Every colour
  // the message list uses is named here and nowhere else — do not inline a hex
  // value into a widget, add a getter here instead. Contrast was measured, not
  // eyeballed; the ratios are recorded in CLAUDE.md.

  /// Outgoing ("own") message bubble.
  Color get bubbleColor => brightness == Brightness.light
      ? const Color(0xFFDCF8C6)
      : const Color(0xFF005C4B);

  /// Text on an outgoing bubble. 15.2:1 light, 6.8:1 dark.
  Color get onBubbleColor => brightness == Brightness.light
      ? const Color(0xFF111B21)
      : const Color(0xFFE9EDEF);

  /// Incoming message bubble: white in light mode, slate in dark.
  Color get incomingBubbleColor => brightness == Brightness.light
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF202C33);

  /// Text on an incoming bubble. 17.5:1 light, 12.1:1 dark.
  Color get onIncomingBubbleColor => onBubbleColor;

  /// The calm background the bubbles sit on. Deliberately a little deeper than
  /// WhatsApp's beige: WhatsApp separates bubbles from the background with a
  /// patterned wallpaper, we have a flat colour, so the separation has to come
  /// from luminance instead (outgoing 1.19:1, incoming 1.37:1 against it).
  Color get chatBackgroundColor => brightness == Brightness.light
      ? const Color(0xFFE3DBD1)
      : const Color(0xFF0B141A);

  /// Timestamps and the small state text. These sit on the chat BACKGROUND,
  /// not on a bubble, so they are measured against it: 5.3:1 light, 8.9:1 dark.
  Color get chatMetaColor => brightness == Brightness.light
      ? const Color(0xFF4A5860)
      : const Color(0xFFA8B6BE);

  /// FrozenGFc #V82: the READ tick. Sending and sent ticks use chatMetaColor
  /// above; only "read" gets its own colour. Measured against the chat
  /// background: 4.0:1 light, 11.6:1 dark — well over the 3:1 bar for icons.
  /// ⚠ Colour is the SECOND cue only. One check versus two carries the meaning,
  /// so the state survives daylight, greyscale and colour blindness.
  Color get chatTickReadColor => brightness == Brightness.light
      ? const Color(0xFF12793A)
      : const Color(0xFF6BE39A);

  Color get secondaryBubbleColor => HSLColor.fromColor(
    brightness == Brightness.light
        ? colorScheme.tertiary
        : colorScheme.tertiaryContainer,
  ).withSaturation(0.5).toColor();
}
