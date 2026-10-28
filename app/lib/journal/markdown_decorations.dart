import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'markdown.dart';

/// Draws what [Markdown.span] leaves room for when decorated: each
/// checklist's box and each divider, over the text below it, which
/// may be an entry being written or read ([EditableText]) or a preview
/// ([RichText]). Where the characters stand is asked of the text's own
/// layout, so the drawing is always where the words are (owner, 27
/// October 2026: a "proper box", in writing as in reading).
class MarkdownDecorations extends SingleChildRenderObjectWidget {
  /// The text drawn below, as the Markdown it is.
  final String text;
  final SmColors colors;

  const MarkdownDecorations({
    super.key,
    required this.text,
    required this.colors,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderMarkdownDecorations(text, colors);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMarkdownDecorations renderObject,
  ) {
    renderObject
      ..text = text
      ..colors = colors;
  }
}

class RenderMarkdownDecorations extends RenderProxyBox {
  RenderMarkdownDecorations(this._text, this._colors);

  String _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    markNeedsPaint();
  }

  SmColors _colors;
  set colors(SmColors value) {
    if (value == _colors) return;
    _colors = value;
    markNeedsPaint();
  }

  // The text's own render object, which knows where each character is.
  RenderBox? _target(RenderObject from) {
    if (from is RenderEditable || from is RenderParagraph) {
      return from as RenderBox;
    }
    RenderBox? found;
    from.visitChildren((child) => found ??= _target(child));
    return found;
  }

  List<Rect> _boxes(RenderBox target, int start, int end) {
    final selection = TextSelection(baseOffset: start, extentOffset: end);
    final boxes = switch (target) {
      RenderEditable editable => editable.getBoxesForSelection(selection),
      RenderParagraph paragraph => paragraph.getBoxesForSelection(selection),
      _ => const <TextBox>[],
    };
    final toHere = target.getTransformTo(this);
    return [
      for (final box in boxes) MatrixUtils.transformRect(toHere, box.toRect()),
    ];
  }

  Rect? _union(List<Rect> rects) =>
      rects.isEmpty ? null : rects.reduce((a, b) => a.expandToInclude(b));

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final child = this.child;
    if (child == null) return;
    final target = _target(child);
    if (target == null || !target.hasSize) return;
    final text = switch (target) {
      RenderEditable editable => editable.text?.toPlainText() ?? '',
      RenderParagraph paragraph => paragraph.text.toPlainText(),
      _ => '',
    };
    // Only what the text below is: a preview may be the start of it.
    if (text.isEmpty || !_text.startsWith(text)) return;
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    for (final (range, ticked) in Markdown.boxes(text)) {
      _paintBox(canvas, target, range, ticked);
    }
    for (final range in Markdown.dividers(text)) {
      _paintDivider(canvas, target, range);
    }
    canvas.restore();
  }

  // A divider: a fine rule the width of the text, through the middle of
  // its line.
  void _paintDivider(Canvas canvas, RenderBox target, TextRange at) {
    final room = _union(_boxes(target, at.start, at.end));
    if (room == null) return;
    final toHere = target.getTransformTo(this);
    final left = MatrixUtils.transformPoint(toHere, Offset.zero).dx;
    final right = MatrixUtils.transformPoint(
      toHere,
      Offset(target.size.width, 0),
    ).dx;
    canvas.drawLine(
      Offset(left, room.center.dy),
      Offset(right, room.center.dy),
      Paint()
        ..color = _colors.textFaint
        ..strokeWidth = 1,
    );
  }

  void _paintBox(Canvas canvas, RenderBox target, TextRange at, bool ticked) {
    final room = _union(_boxes(target, at.start, at.end));
    if (room == null) return;
    final side = math.min(room.height * 0.6, room.width * 0.75);
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: room.center, width: side, height: side),
      Radius.circular(side * 0.24),
    );
    if (ticked) {
      canvas.drawRRect(box, Paint()..color = _colors.accent);
      final tick = Path()
        ..moveTo(box.left + side * 0.24, box.top + side * 0.52)
        ..lineTo(box.left + side * 0.43, box.top + side * 0.7)
        ..lineTo(box.left + side * 0.77, box.top + side * 0.3);
      canvas.drawPath(
        tick,
        Paint()
          ..color = _colors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.6, side * 0.13)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawRRect(
        box,
        Paint()
          ..color = _colors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.4, side * 0.09),
      );
    }
  }
}
