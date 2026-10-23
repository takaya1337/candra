import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'wheel_row.dart';

/// Two wheels, hours and minutes, in the manner of the date picker.
class TimePicker extends StatefulWidget {
  final int minuteOfDay;
  final ValueChanged<int> onChanged;

  const TimePicker({
    super.key,
    required this.minuteOfDay,
    required this.onChanged,
  });

  @override
  State<TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<TimePicker> {
  static const _itemExtent = 36.0;

  late final _hours = FixedExtentScrollController(
    initialItem: widget.minuteOfDay ~/ 60,
  );
  late final _minutes = FixedExtentScrollController(
    initialItem: widget.minuteOfDay % 60,
  );

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _onWheelMoved() {
    HapticFeedback.selectionClick();
    widget.onChanged(_hours.selectedItem * 60 + _minutes.selectedItem);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

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
            Expanded(child: _wheel(const ValueKey('picker-hour'), _hours, 24)),
            Text(
              ':',
              style: theme.type.body.copyWith(color: theme.colors.textPrimary),
            ),
            Expanded(
              child: _wheel(const ValueKey('picker-minute'), _minutes, 60),
            ),
          ],
        ),
      ],
    );
  }

  Widget _wheel(Key key, FixedExtentScrollController controller, int count) {
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
      onSelectedItemChanged: (_) => _onWheelMoved(),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) => WheelRow(
          controller: controller,
          index: index,
          child: Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: theme.type.body.copyWith(color: theme.colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
