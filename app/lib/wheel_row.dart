import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// A row of a wheel that can be touched as well as turned to: a touch on
/// a row above or below the middle turns the wheel until it is in the
/// middle, as if it had been turned there by hand.
class WheelRow extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int index;
  final Widget child;

  const WheelRow({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final motion = SmTheme.of(context).motion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!controller.hasClients || controller.selectedItem == index) return;
        controller.animateToItem(
          index,
          duration: motion.medium,
          curve: motion.curve,
        );
      },
      child: child,
    );
  }
}
