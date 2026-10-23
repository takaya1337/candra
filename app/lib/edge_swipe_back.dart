import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// On an iPhone, a screen opened inside a room is drawn off from the left
/// edge to go back, as in most of its apps: a finger that starts at the
/// left edge and moves right. Only that: the swipe that rewards the
/// intuition of going back, and no other (owner, 20 October 2026; it
/// was from either edge before). The screen follows the
/// finger; let go far enough along, or quickly enough, and it is the same
/// as the back button (it goes through the screen's own back handling, so
/// an open picker or a narrowed list steps back first, as the button
/// would). Let go short of that and it slides home again.
///
/// Android has the same gesture from the phone itself, so this does
/// nothing there.
class EdgeSwipeBack extends StatefulWidget {
  final Widget child;

  const EdgeSwipeBack({super.key, required this.child});

  /// How far in from each edge a finger must start.
  static const edge = 24.0;

  /// Share of the width past which letting go goes back.
  static const enough = 0.3;

  /// Speed, logical pixels a second, at which a flick goes back however
  /// short it was.
  static const flick = 700.0;

  /// How far, in logical pixels, the screen [context] is in has been
  /// drawn aside; 0 where it has not, or where there is none. The phone's
  /// own bar stands still while a screen is drawn (see `NativeBar`): it
  /// takes the screen's place as if it had not moved.
  static double shiftOf(BuildContext context) {
    final state = context.findAncestorStateOfType<_EdgeSwipeBackState>();
    return state == null ? 0 : state._drawn.value * state._width;
  }

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack>
    with SingleTickerProviderStateMixin {
  // How far the screen has been drawn, as a share of its width: positive
  // to the right (from the left edge), negative to the left.
  late final _drawn = AnimationController.unbounded(vsync: this);

  // Which edge the finger started at: always the left, 1.
  double _side = 1;
  double _width = 1;

  @override
  void dispose() {
    _drawn.dispose();
    super.dispose();
  }

  bool _atEdge(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final x = box.globalToLocal(global).dx;
    _width = box.size.width;
    if (x <= EdgeSwipeBack.edge) {
      _side = 1;
      return true;
    }
    return false;
  }

  void _update(DragUpdateDetails details) {
    final moved = _drawn.value + details.delta.dx / _width;
    // Only towards the far side, never past the edge it started at.
    _drawn.value = _side > 0 ? moved.clamp(0.0, 1.0) : moved.clamp(-1.0, 0.0);
  }

  Future<void> _end(DragEndDetails details) async {
    final speed = details.velocity.pixelsPerSecond.dx * _side;
    final far = _drawn.value.abs() >= EdgeSwipeBack.enough;
    if (speed >= EdgeSwipeBack.flick || (far && speed > -EdgeSwipeBack.flick)) {
      final route = ModalRoute.of(context);
      await Navigator.of(context).maybePop();
      if (!mounted) return;
      // Gone: it goes on the way it was thrown as it fades. Kept (the
      // screen stepped back within itself): home again.
      if (route == null || !route.isCurrent) {
        _drawn.animateTo(
          _side,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }
    _home();
  }

  void _home() => _drawn.animateTo(
    0,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return widget.child;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _EdgeDrag: GestureRecognizerFactoryWithHandlers<_EdgeDrag>(
          () => _EdgeDrag(_atEdge),
          (drag) => drag
            ..onStart = ((_) => _drawn.stop())
            ..onUpdate = _update
            ..onEnd = _end
            ..onCancel = _home,
        ),
      },
      // Always in the same layers, drawn aside or not: swapping them in
      // and out at the start and end of a draw would make the whole
      // screen anew each time. Moved as a picture: nothing in the screen
      // is painted again while it follows the finger.
      child: AnimatedBuilder(
        animation: _drawn,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(_drawn.value, 0),
          child: child,
        ),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// A sideways drag that only starts at an edge, and starts sooner than
/// anything sideways inside the screen (a row drawn to delete, a strip of
/// days), so that from the edge it is the one that wins.
class _EdgeDrag extends HorizontalDragGestureRecognizer {
  final bool Function(Offset global) atEdge;

  _EdgeDrag(this.atEdge);

  @override
  bool isPointerAllowed(PointerEvent event) =>
      super.isPointerAllowed(event) && atEdge(event.position);

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => globalDistanceMoved.abs() > 8;
}
