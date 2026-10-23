import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// How everything that scrolls scrolls in the app: with a thin, faint bar
/// along its edge, always shown, so that what goes on past the edge of
/// the screen is seen to (down the right of a list, along the foot of a
/// row that runs sideways). A list that fits shows no bar.
///
/// Not on what leafs (the months, the years, the days: their pages are
/// the bar) nor on the wheels, whose turning is plain to see.
class CandraScrollBehavior extends ScrollBehavior {
  const CandraScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final controller = details.controller;
    if (controller is PageController ||
        controller is FixedExtentScrollController) {
      return child;
    }
    return ScrollHint(child: child);
  }
}

/// The bar itself: read from what the list says of itself as it is laid
/// out and scrolled, not from its controller, so that lists sharing one
/// (as every list on a screen may share the screen's) each have their own.
/// It only shows; it is not dragged.
class ScrollHint extends StatefulWidget {
  final Widget child;

  const ScrollHint({super.key, required this.child});

  static const thickness = 2.5;

  @override
  State<ScrollHint> createState() => _ScrollHintState();
}

/// How the bar of the lists under it is drawn, where the plain faint bar
/// along the very edge will not do: in a colour of its own, and kept in
/// from the edges ([inset]): from a frame's rounded corners, so the bar
/// never runs over the frame's line (the journal's folders, the category
/// capsule), or further from what it lies beside (the reminder rail).
class ScrollHintStyle extends InheritedWidget {
  final Color? color;
  final EdgeInsets inset;

  const ScrollHintStyle({
    super.key,
    this.color,
    this.inset = EdgeInsets.zero,
    required super.child,
  });

  static ScrollHintStyle? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScrollHintStyle>();

  @override
  bool updateShouldNotify(ScrollHintStyle old) =>
      old.color != color || old.inset != inset;
}

class _ScrollHintState extends State<ScrollHint> {
  // Kept outside the build: a list may speak while it is being laid out,
  // and what it says only repaints the bar.
  final _metrics = ValueNotifier<ScrollMetrics?>(null);

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  bool _heard(Notification notification) {
    if (notification
        case ScrollNotification(depth: 0, :final metrics) ||
            ScrollMetricsNotification(depth: 0, :final metrics)) {
      _metrics.value = metrics.copyWith();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _heard,
      child: CustomPaint(
        foregroundPainter: _HintPainter(
          metrics: _metrics,
          color:
              ScrollHintStyle.of(context)?.color ??
              SmTheme.of(context).colors.textFaint.withValues(alpha: 0.5),
          inset: ScrollHintStyle.of(context)?.inset ?? EdgeInsets.zero,
        ),
        child: widget.child,
      ),
    );
  }
}

class _HintPainter extends CustomPainter {
  final ValueNotifier<ScrollMetrics?> metrics;
  final Color color;
  final EdgeInsets inset;

  _HintPainter({
    required this.metrics,
    required this.color,
    required this.inset,
  }) : super(repaint: metrics);

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics.value;
    if (m == null || !m.hasContentDimensions || !m.hasViewportDimension) {
      return;
    }
    final extent = m.maxScrollExtent - m.minScrollExtent;
    if (extent <= 0 || !extent.isFinite) return;
    const thickness = ScrollHint.thickness;
    final vertical = m.axis == Axis.vertical;
    // The track, kept in from the ends by the inset along it.
    final from = vertical ? inset.top : inset.left;
    final track =
        (vertical
            ? size.height - inset.vertical
            : size.width - inset.horizontal) -
        4;
    final content = extent + m.viewportDimension;
    final length = (track * m.viewportDimension / content).clamp(24.0, track);
    var along = ((m.pixels - m.minScrollExtent) / extent).clamp(0.0, 1.0);
    if (m.axisDirection == AxisDirection.up ||
        m.axisDirection == AxisDirection.left) {
      along = 1 - along;
    }
    final start = from + 2 + (track - length) * along;
    final rect = vertical
        ? Rect.fromLTWH(
            size.width - thickness - 1 - inset.right,
            start,
            thickness,
            length,
          )
        : Rect.fromLTWH(
            start,
            size.height - thickness - 1 - inset.bottom,
            length,
            thickness,
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(thickness)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_HintPainter old) =>
      old.metrics != metrics || old.color != color || old.inset != inset;
}

/// Room under a row that scrolls sideways for its bar, taken from what is
/// already under it (a bottom bar's padding) rather than added to it: the
/// row is laid out [room] taller, the extra left empty for the bar, and
/// takes up only its own height. The buttons stand as far from the bar as
/// the pills of a [PillRow] do (owner, 20 October 2026, the format bar).
class ScrollHintRoom extends SingleChildRenderObjectWidget {
  /// A [PillRow]'s height less its pills'.
  static const room = 12.0;

  const ScrollHintRoom({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRoom();
}

class _RenderRoom extends RenderProxyBox {
  @override
  void performLayout() {
    final child = this.child!;
    child.layout(
      constraints.copyWith(
        maxHeight: constraints.maxHeight + ScrollHintRoom.room,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(child.size.width, child.size.height - ScrollHintRoom.room),
    );
  }
}
