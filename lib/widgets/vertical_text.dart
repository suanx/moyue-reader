import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 竖排文本（从右向左分列，符合中文古籍阅读习惯）
class VerticalTextView extends StatelessWidget {
  const VerticalTextView({
    super.key,
    required this.text,
    required this.style,
    this.columnGapFactor = 1.6,
    this.charGapFactor = 1.12,
  });

  final String text;
  final TextStyle style;
  final double columnGapFactor;
  final double charGapFactor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerticalTextPainter(
        text: text,
        style: style,
        columnGapFactor: columnGapFactor,
        charGapFactor: charGapFactor,
      ),
      size: Size.infinite,
    );
  }
}

class _VerticalTextPainter extends CustomPainter {
  _VerticalTextPainter({
    required this.text,
    required this.style,
    required this.columnGapFactor,
    required this.charGapFactor,
  });

  final String text;
  final TextStyle style;
  final double columnGapFactor;
  final double charGapFactor;

  static final RegExp _latin = RegExp(r'[A-Za-z0-9@#\$%\^&\*\(\)\[\]{}/\\+=_\-]');

  @override
  void paint(Canvas canvas, Size size) {
    final fontSize = style.fontSize ?? 18;
    final color = style.color ?? Colors.black;
    final charStep = fontSize * charGapFactor;
    final columnWidth = fontSize * columnGapFactor;

    var x = size.width - columnWidth / 2;
    var y = 0.0;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\n') {
        x -= columnWidth;
        y = 0;
        continue;
      }
      if (y + charStep > size.height) {
        x -= columnWidth;
        y = 0;
        if (x < 0) break;
      }

      final painter = TextPainter(
        text: TextSpan(text: ch, style: style.copyWith(color: color)),
        textDirection: TextDirection.ltr,
      )..layout();

      if (ch.length == 1 && _latin.hasMatch(ch)) {
        // 英文与数字旋转 90°
        canvas.save();
        canvas.translate(x, y + fontSize / 2);
        canvas.rotate(math.pi / 2);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      } else {
        painter.paint(canvas, Offset(x - painter.width / 2, y));
      }
      y += charStep;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalTextPainter old) =>
      old.text != text || old.style != style;
}
