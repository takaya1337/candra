import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A label that changes through an iris: the old content is swallowed from
/// its edges inward, then the new content opens out from the centre.
///
/// The widget keeps the old content's size until the iris has closed, then
/// takes the new size, so a container can resize in step with the opening.
class IrisLabel extends StatefulWidget {
  /// How long the iris takes to open. Containers that resize around the
  /// label should use the same duration and [openCurve].
  static const openDuration = Duration(milliseconds: 50);
  static const openCurve = Curves.easeOutCubic;

  final String text;
  final TextStyle style;

  /// Shows a dot before the text. It changes under the iris with the text.
  final bool marked;
  final Color markColor;

  const IrisLabel({
    super.key,
    required this.text,
    required this.style,
    this.marked = false,
    this.markColor = const Color(0x00000000),
  });

  @override
  State<IrisLabel> createState() => _IrisLabelState();
}

class _IrisLabelState extends State<IrisLabel>
    with SingleTickerProviderStateMixin {
  static const _close = Duration(milliseconds: 50);

  // How much of the iris radius the soft edge takes up.
  static const _feather = 0.45;

  // 1 = fully open, 0 = fully closed.
  late final AnimationController _iris = AnimationController(
    vsync: this,
    value: 1,
  )..addStatusListener(_onStatus);

  late (String, bool) _shown = _wanted;

  (String, bool) get _wanted => (widget.text, widget.marked);

  @override
  void didUpdateWidget(IrisLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_wanted == _shown) {
      _openUp();
    } else {
      // Close from wherever the iris is now. A change arriving mid-close
      // just lets the close finish and opens on the latest content.
      _iris.animateTo(
        0,
        duration: _close * _iris.value,
        curve: Curves.easeInCubic,
      );
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _iris.value != 0) return;
    setState(() => _shown = _wanted);
    _openUp();
  }

  void _openUp() {
    if (_iris.value == 1) return;
    _iris.animateTo(
      1,
      duration: IrisLabel.openDuration * (1 - _iris.value),
      curve: IrisLabel.openCurve,
    );
  }

  @override
  void dispose() {
    _iris.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (text, marked) = _shown;

    return AnimatedBuilder(
      animation: _iris,
      builder: (context, child) {
        if (_iris.value == 1) return child!;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => _irisShader(bounds, _iris.value),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (marked) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: widget.markColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Cut short with an ellipsis if the button is not allowed the
          // room for all of it.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
          ),
        ],
      ),
    );
  }

  /// Opaque inside the iris, fading to nothing across a soft edge.
  static ui.Shader _irisShader(Rect bounds, double opening) {
    const opaque = Color(0xFFFFFFFF);
    const clear = Color(0x00FFFFFF);
    final reach =
        math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height) /
        2;
    final edge = opening * (1 + _feather);
    return ui.Gradient.radial(
      bounds.center,
      reach,
      const [opaque, opaque, clear],
      [0, (edge - _feather).clamp(0.0, 1.0), edge.clamp(0.0, 1.0)],
    );
  }
}
