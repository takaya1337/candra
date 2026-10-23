import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// How a row of cards in a lower panel moves (owner, 22 October 2026:
/// inertial scroll in every panel's cards): a flick carries it on, as
/// far as its speed would carry anything that slows by friction, and it
/// comes to rest with a card at the centre, slowing into it rather than
/// springing back.
///
/// [slot] is how far apart the cards stand, from the scroll's own
/// measures: a fixed length, or for a [PageView] a share of the viewport
/// ([InertialSnapPhysics.pages]), whose pages then must not snap
/// themselves (`pageSnapping: false`).
class InertialSnapPhysics extends ScrollPhysics {
  final double Function(ScrollMetrics position) slot;

  const InertialSnapPhysics(this.slot, {super.parent});

  /// For a [PageView] whose pages are [fraction] of the viewport.
  factory InertialSnapPhysics.pages(double fraction, {ScrollPhysics? parent}) =>
      InertialSnapPhysics(
        (position) => position.viewportDimension * fraction,
        parent: parent,
      );

  /// The friction a flick slows by: the platform's own scrolling's.
  static const _drag = 0.135;

  @override
  InertialSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      InertialSnapPhysics(slot, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    final gap = slot(position);
    if (gap <= 0) return super.createBallisticSimulation(position, velocity);
    final start = position.pixels;
    // Where friction alone would leave it, to the nearest card.
    final coast = velocity.abs() < tolerance.velocity
        ? start
        : FrictionSimulation(_drag, start, velocity).finalX;
    final target = ((coast / gap).roundToDouble() * gap).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - start).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    // Going the way the flick goes: slow into the card, by friction
    // tuned to stop there.
    if (velocity.abs() >= tolerance.velocity &&
        (target - start).sign == velocity.sign &&
        (target - start).abs() > tolerance.distance) {
      return FrictionSimulation.through(
        start,
        target,
        velocity,
        tolerance.velocity * velocity.sign,
      );
    }
    // Too slow to reach one, or the edge is behind: settle onto it.
    return ScrollSpringSimulation(
      spring,
      start,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
