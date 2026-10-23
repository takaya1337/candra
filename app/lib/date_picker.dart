import 'package:flutter/gestures.dart';

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'strings.dart';
import 'wheel_row.dart';

/// Three wheels (day, month, year) that report every notch as it passes.
class DatePicker extends StatefulWidget {
  static const firstYear = 1900;
  static const lastYear = 2100;

  final CivilDate date;
  final ValueChanged<CivilDate> onChanged;

  /// Passed in so wheels fading out keep their own month names.
  final Strings strings;

  /// Whether the wheels keep clear of the sides, as they do when they
  /// have the lower panel to themselves.
  final bool inset;

  const DatePicker({
    super.key,
    required this.date,
    required this.strings,
    required this.onChanged,
    this.inset = true,
  });

  @override
  State<DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<DatePicker> {
  static const _itemExtent = 36.0;

  late CivilDate _date = widget.date;
  late final _days = FixedExtentScrollController(initialItem: _date.day - 1);
  late final _months = FixedExtentScrollController(
    initialItem: _date.month - 1,
  );
  late final _years = FixedExtentScrollController(
    initialItem: _date.year - DatePicker.firstYear,
  );

  // True while the wheels are being moved by code rather than by a finger.
  bool _syncing = false;

  @override
  void didUpdateWidget(DatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a date pushed from outside moves the wheels; a rebuild that
    // merely repeats the old date must not drag them back mid-spin.
    if (widget.date != oldWidget.date && widget.date != _date) {
      _date = widget.date;
      _syncWheels();
    }
  }

  @override
  void dispose() {
    _days.dispose();
    _months.dispose();
    _years.dispose();
    super.dispose();
  }

  // Runs after the frame so the day wheel already has the right item count.
  void _syncWheels() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncing = true;
      _years.jumpToItem(_date.year - DatePicker.firstYear);
      _months.jumpToItem(_date.month - 1);
      _days.jumpToItem(_date.day - 1);
      _syncing = false;
    });
  }

  void _onWheelMoved() {
    if (_syncing) return;
    final year = DatePicker.firstYear + _years.selectedItem;
    final month = _months.selectedItem + 1;
    final wheelDay = _days.selectedItem + 1;
    final day = math.min(wheelDay, CivilDate.daysInMonth(year, month));
    final date = CivilDate(year, month, day);
    if (date == _date) return;

    HapticFeedback.selectionClick();
    // The wheels repaint themselves; a rebuild is only needed when the
    // number of days on the day wheel changes.
    final daysChanged =
        CivilDate.daysInMonth(date.year, date.month) !=
        CivilDate.daysInMonth(_date.year, _date.month);
    _date = date;
    if (daysChanged) setState(() {});
    if (day != wheelDay) _syncWheels();
    widget.onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.inset ? theme.spacing.lg : 0,
      ),
      child: Stack(
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
                flex: 2,
                child: _wheel(
                  key: const ValueKey('picker-day'),
                  controller: _days,
                  count: CivilDate.daysInMonth(_date.year, _date.month),
                  label: (index) => '${index + 1}',
                ),
              ),
              Expanded(
                flex: 4,
                child: _wheel(
                  key: const ValueKey('picker-month'),
                  controller: _months,
                  count: 12,
                  label: (index) => widget.strings.monthNames[index],
                ),
              ),
              Expanded(
                flex: 3,
                child: _wheel(
                  key: const ValueKey('picker-year'),
                  controller: _years,
                  count: DatePicker.lastYear - DatePicker.firstYear + 1,
                  label: (index) => '${DatePicker.firstYear + index}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
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
      onSelectedItemChanged: (_) => _onWheelMoved(),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) => WheelRow(
          controller: controller,
          index: index,
          child: Center(
            child: Text(
              label(index),
              style: theme.type.body.copyWith(color: theme.colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
