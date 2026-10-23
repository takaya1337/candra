import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A press target with two actions: a quick tap, and a deliberate hold.
///
/// While held, [builder] receives the hold's progress from 0 to 1 so the
/// child can show it filling. Reaching 1 fires [onHold] with a haptic tick.
/// Letting go early cancels the hold without firing either action.
class SmHoldPressable extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onHold;
  final Duration holdDuration;
  final Widget Function(BuildContext context, double progress) builder;

  const SmHoldPressable({
    super.key,
    required this.onTap,
    required this.onHold,
    required this.builder,
    this.holdDuration = const Duration(milliseconds: 650),
  });

  @override
  State<SmHoldPressable> createState() => _SmHoldPressableState();
}

class _SmHoldPressableState extends State<SmHoldPressable>
    with SingleTickerProviderStateMixin {
  // A release inside this window is a tap; the fill only starts after it,
  // so ordinary taps never flash.
  static const _tapWindow = Duration(milliseconds: 160);
  static const _retreat = Duration(milliseconds: 260);

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: _tapWindow + widget.holdDuration,
  )..addStatusListener(_onStatus);

  bool _down = false;
  bool _held = false;

  double get _tapFraction =>
      _tapWindow.inMicroseconds / _press.duration!.inMicroseconds;

  double get _progress =>
      ((_press.value - _tapFraction) / (1 - _tapFraction)).clamp(0.0, 1.0);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_down) return;
    _held = true;
    HapticFeedback.mediumImpact();
    widget.onHold();
    _press.animateBack(0, duration: _retreat, curve: Curves.easeOut);
  }

  void _onDown(TapDownDetails details) {
    _down = true;
    _held = false;
    _press.forward(from: 0);
  }

  void _onUp(TapUpDetails details) {
    _down = false;
    if (_held) return;
    final wasTap = _press.value <= _tapFraction;
    _press.animateBack(0, duration: _retreat, curve: Curves.easeOut);
    if (wasTap) widget.onTap();
  }

  void _onCancel() {
    _down = false;
    if (!_held) {
      _press.animateBack(0, duration: _retreat, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onDown,
      onTapUp: _onUp,
      onTapCancel: _onCancel,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) => widget.builder(context, _progress),
      ),
    );
  }
}

/// Paints a disc growing from the centre until it covers the whole area.
class SmRadialFillPainter extends CustomPainter {
  final double progress;
  final Color color;

  const SmRadialFillPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final reach = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    canvas.drawCircle(
      size.center(Offset.zero),
      reach / 2 * Curves.easeOut.transform(progress),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(SmRadialFillPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
