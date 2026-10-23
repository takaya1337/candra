import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Putting small marks exactly on the screen's own pixels.
///
/// The layout places things at fractions of a pixel. Text and large shapes
/// do not mind, but a row of small coloured dots does: each dot straddles
/// pixel rows, with a faint row above and a fainter one below, and on a
/// screen whose red, green and blue lights are not stacked in the same
/// spot, dots of different colours then seem to sit at slightly different
/// heights.
abstract final class PixelSnap {
  /// Tells whatever has snapped itself to look again: the screen has come
  /// to rest after something (a zoom) moved it in a way other than
  /// scrolling, and what was drawn in the middle of that is off.
  static final settled = _Settled();

  /// Where something at [local] should be drawn so that it lands on a
  /// whole pixel, given that the thing drawing it starts at [origin] on
  /// the screen.
  static double position(double local, double origin, double pixelRatio) =>
      ((origin + local) * pixelRatio).roundToDouble() / pixelRatio - origin;

  /// [length] as the nearest whole number of pixels.
  static double length(double length, double pixelRatio) =>
      (length * pixelRatio).roundToDouble() / pixelRatio;

  /// The radius nearest [diameter] / 2 that makes a dot a whole, even
  /// number of pixels across: its centre can then sit on the line between
  /// two pixels and the dot fill whole pixels on every side.
  static double radius(double diameter, double pixelRatio) =>
      (diameter * pixelRatio / 2).roundToDouble() / pixelRatio;

  /// Where [box]'s corner is on the screen once it has come to rest.
  ///
  /// Inside a page that scrolls, that is the page's place in the scroller
  /// plus the scroller's own. Where the page happens to be while it is
  /// drawn, part-way through a swipe or waiting off screen, is beside the
  /// point.
  static Offset restingOrigin(RenderBox box) {
    RenderObject page = box;
    while (page.parent != null && page.parent is! RenderSliver) {
      page = page.parent!;
    }
    final Object? viewport = RenderAbstractViewport.maybeOf(box);
    if (page.parent == null || viewport is! RenderBox) {
      return box.localToGlobal(Offset.zero);
    }
    return box.localToGlobal(Offset.zero, ancestor: page) +
        viewport.localToGlobal(Offset.zero);
  }
}

class _Settled extends ChangeNotifier {
  void now() => notifyListeners();
}
