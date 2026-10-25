import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../wheel_row.dart';

/// Two wheels in the manner of the date picker, the second depending on
/// the first: turn the first to a heading, and the second offers what is
/// under it. Every notch is reported as it passes.
class TwoWheels extends StatefulWidget {
  /// Names the wheels for tests: `<name>-first` and `<name>-second-<i>`,
  /// i being where the first wheel stands.
  final String name;
  final List<String> headings;

  /// What is offered under each heading.
  final List<String> Function(int heading) under;

  /// Where the wheels stand to begin with.
  final int heading;
  final int Function(int heading) chosen;
  final void Function(int heading, int choice) onChanged;

  /// How the width is shared between the two.
  final int firstFlex;
  final int secondFlex;

  /// Drawn before each row of the second wheel, when given: a scheme's
  /// colours beside its name.
  final Widget Function(int heading, int choice)? secondLead;

  const TwoWheels({
    super.key,
    required this.name,
    required this.headings,
    required this.under,
    required this.heading,
    required this.chosen,
    required this.onChanged,
    this.firstFlex = 4,
    this.secondFlex = 5,
    this.secondLead,
  });

  @override
  State<TwoWheels> createState() => _TwoWheelsState();
}

class _TwoWheelsState extends State<TwoWheels> {
  static const _itemExtent = 36.0;

  late int _heading = widget.heading;
  late final _first = FixedExtentScrollController(initialItem: _heading);
  late var _second = FixedExtentScrollController(
    initialItem: widget.chosen(_heading),
  );

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _onHeading(int index) {
    HapticFeedback.selectionClick();
    final old = _second;
    setState(() {
      _heading = index;
      // A new wheel for the new heading, where that one stands.
      _second = FixedExtentScrollController(initialItem: widget.chosen(index));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    widget.onChanged(index, _second.initialItem);
  }

  void _onChoice(int index) {
    HapticFeedback.selectionClick();
    widget.onChanged(_heading, index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final offered = widget.under(_heading);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: _itemExtent,
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: widget.firstFlex,
              child: _wheel(
                ValueKey('${widget.name}-first'),
                _first,
                widget.headings,
                _onHeading,
              ),
            ),
            Expanded(
              flex: widget.secondFlex,
              child: _wheel(
                // One wheel a heading: each has its own length.
                ValueKey('${widget.name}-second-$_heading'),
                _second,
                offered,
                _onChoice,
                lead: widget.secondLead == null
                    ? null
                    : (choice) => widget.secondLead!(_heading, choice),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _wheel(
    Key key,
    FixedExtentScrollController controller,
    List<String> labels,
    ValueChanged<int> onMoved, {
    Widget Function(int index)? lead,
  }) {
    final theme = SmTheme.of(context);

    return ListWheelScrollView.useDelegate(
      key: key,
      controller: controller,
      itemExtent: _itemExtent,
      diameterRatio: 1.4,
      overAndUnderCenterOpacity: 0.35,
      physics: const FixedExtentScrollPhysics(),
      // Counted from where the finger went down, so the rows that can
      // be touched (WheelRow) take nothing from the turn.
      dragStartBehavior: DragStartBehavior.down,
      onSelectedItemChanged: onMoved,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: labels.length,
        builder: (context, index) => WheelRow(
          controller: controller,
          index: index,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lead != null) ...[
                    lead(index),
                    SizedBox(width: theme.spacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      labels[index],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: theme.type.label.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
