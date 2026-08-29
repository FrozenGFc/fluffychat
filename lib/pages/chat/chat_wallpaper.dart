// FrozenGFc #V91: the chat wallpaper.
//
// A quiet, tileable texture drawn from primitives — circles, arcs and short
// strokes on a staggered grid. No image asset, nothing borrowed, nothing traced.
//
// ⚠ THE POINT IS THAT IT STAYS QUIET. The motif colour already carries its own
// low alpha (see chatWallpaperInk in themes.dart); do not "make it visible" by
// raising that here. It is meant to be felt rather than seen — at normal
// reading distance it should read as paper texture, not as a drawing.
//
// ⚠ shouldRepaint is false and the whole thing sits under a RepaintBoundary:
// the pattern never changes, so it must never cost a frame while the timeline
// scrolls above it.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fluffychat/config/themes.dart';

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ChatWallpaperPainter(color: theme.chatWallpaperInk),
        size: Size.infinite,
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  final Color color;

  const _ChatWallpaperPainter({required this.color});

  /// One tile of the repeat. Everything below is expressed as a fraction of it,
  /// so the motif scales with this single number.
  static const double _tile = 64.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cols = (size.width / _tile).ceil() + 1;
    final rows = (size.height / _tile).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      // Every other row is offset by half a tile: a staggered grid reads as
      // texture, a square one reads as graph paper.
      final dy = row * _tile;
      final stagger = row.isOdd ? _tile / 2 : 0.0;
      for (var col = 0; col < cols; col++) {
        final dx = col * _tile - stagger;
        _motif(canvas, Offset(dx, dy), stroke, fill, (row + col) % 3);
      }
    }
  }

  /// Three variants, cycled by position, so the eye does not lock onto a grid.
  void _motif(Canvas canvas, Offset o, Paint stroke, Paint fill, int variant) {
    switch (variant) {
      case 0:
        // an open ring with a small companion dot
        canvas.drawCircle(o + const Offset(16, 16), 6.5, stroke);
        canvas.drawCircle(o + const Offset(34, 30), 1.6, fill);
        break;
      case 1:
        // a soft open arc, like a thread
        final rect = Rect.fromCircle(
          center: o + const Offset(30, 20),
          radius: 8.0,
        );
        canvas.drawArc(rect, math.pi * 0.15, math.pi * 1.15, false, stroke);
        canvas.drawCircle(o + const Offset(12, 40), 1.6, fill);
        break;
      default:
        // two short diagonal strokes
        canvas.drawLine(
          o + const Offset(14, 34),
          o + const Offset(24, 24),
          stroke,
        );
        canvas.drawLine(
          o + const Offset(30, 40),
          o + const Offset(38, 32),
          stroke,
        );
        canvas.drawCircle(o + const Offset(40, 14), 1.6, fill);
        break;
    }
  }

  @override
  bool shouldRepaint(_ChatWallpaperPainter oldDelegate) =>
      oldDelegate.color != color;
}
