import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'day_reading.dart';
import 'pixel_snap.dart';
import 'strings.dart';
import 'system_months.dart';

/// Six Monday-first weeks covering one month: a Gregorian month, or, on
/// the calendar under the Chinese, Hijri or Javanese system, a month of
/// that system ([shifted]; owner, 21 October 2026), each day then
/// numbered as the system counts it with its Gregorian day written under
/// it. The geometry never changes.
///
/// Along the bottom of each cell is room for up to [maxDots] dots, in
/// whatever colours [dotsOf] gives for the day: on the calendar, one per
/// category with a reminder that day.
class MonthGrid extends StatelessWidget {
  /// The month shown.
  final SystemMonth span;

  /// Whether [span] is a month of [system], numbered as it counts.
  final bool shifted;

  /// The Gregorian year and month [span] begins in.
  int get year => span.first.year;
  int get month => span.first.month;
  final CalendarSystem system;
  final CivilDate today;
  final CivilDate selected;
  final ValueChanged<CivilDate> onSelect;

  /// The colours of a day's dots. Only the first [maxDots] are shown.
  final List<Color> Function(CivilDate date)? dotsOf;

  static const maxDots = 4;

  const MonthGrid({
    super.key,
    required this.span,
    this.shifted = false,
    required this.system,
    required this.today,
    required this.selected,
    required this.onSelect,
    this.dotsOf,
  });

  @override
  Widget build(BuildContext context) {
    final first = span.first;
    // The Gregorian months' names, for the days written under a system's
    // own: only read where there are such.
    final months = shifted ? Strings.of(context).monthNames : const <String>[];
    final gridStart = first.addDays(-Weekday.of(first).index);

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            for (var week = 0; week < 6; week++)
              Expanded(
                child: Row(
                  children: [
                    for (var day = 0; day < 7; day++)
                      Expanded(
                        child: _cell(gridStart.addDays(week * 7 + day), months),
                      ),
                  ],
                ),
              ),
          ],
        ),
        // Every cell's entry dots, drawn in one go over the grid.
        if (dotsOf != null)
          IgnorePointer(
            child: EntryDots(
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
              cells: [
                for (var i = 0; i < 42; i++)
                  (
                    colors: (dotsOf?.call(gridStart.addDays(i)) ?? const [])
                        .take(maxDots)
                        .toList(),
                    inMonth: span.contains(gridStart.addDays(i)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(CivilDate date, List<String> months) => _DayCell(
    date: date,
    // The system's own day, with the Gregorian under it; the first of a
    // Gregorian month under its month's short name.
    number: shifted ? SystemCalendar.of(system).dayOf(date) : date.day,
    label: shifted
        ? (date.day == 1
              ? months[date.month - 1].substring(0, 3)
              : '${date.day}')
        : system.cellLabel(date),
    // In the Chinese calendar a day also has its element.
    element: system == CalendarSystem.chinese && ChineseDate.supports(date)
        ? ChineseDate.dayUnsur(date)
        : null,
    inMonth: span.contains(date),
    isToday: date == today,
    isSelected: date == selected,
    onTap: () => onSelect(date),
  );
}

class _DayCell extends StatelessWidget {
  final CivilDate date;
  final int number;
  final String? label;

  /// The element of the day, shown as its coloured character to the right
  /// of the label.
  final Unsur? element;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.number,
    required this.label,
    required this.element,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;

    // Outside days sit well back so the month itself reads cleanly. Done
    // with colour, not an Opacity layer: forty-odd layers per page made
    // month swipes drop frames.
    final number = inMonth
        ? colors.textPrimary
        : colors.textFaint.withValues(alpha: 0.5);
    final caption = inMonth
        ? colors.textSecondary
        : colors.textFaint.withValues(alpha: 0.5);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(EntryDots.cellMargin),
        decoration: BoxDecoration(
          color: isSelected ? colors.surfaceRaised : null,
          border: isToday ? Border.all(color: colors.accent) : null,
          borderRadius: BorderRadius.circular(theme.radii.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${this.number}',
              style: theme.type.body.copyWith(color: number),
            ),
            // Fixed height, so the day number sits at the same place whether
            // or not the system has a label for this day.
            SizedBox(
              height: 14,
              child: Text.rich(
                TextSpan(
                  text: label ?? '',
                  children: [
                    if (element != null)
                      TextSpan(
                        text: ' ${Strings.dayElementHanzi(date)}',
                        style: TextStyle(
                          color: elementColors[element]!.withValues(
                            alpha: inMonth ? 1 : 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
                style: theme.type.caption.copyWith(color: caption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The entry dots of all forty-two cells of a month grid.
///
/// A cell's dots sit a fixed distance above the bottom line of its frame,
/// in four places across the middle of its width, filled from the left.
///
/// Every dot is then moved the fraction of a pixel it takes to land
/// exactly on the screen's own pixels; see [PixelSnap].
class EntryDots extends LeafRenderObjectWidget {
  /// Six rows of seven, first row first.
  final List<({List<Color> colors, bool inMonth})> cells;
  final double pixelRatio;

  const EntryDots({super.key, required this.cells, required this.pixelRatio});

  /// The gap kept clear around a cell's frame.
  static const cellMargin = 2.0;

  /// A dot's width.
  static const size = 4.0;

  /// How far a dot's centre sits above the bottom line of the cell's
  /// frame: clear of the rounded corners of a bordered cell.
  static const lift = 8.0;

  /// How much of the frame's width the four places take up, centred.
  static const reach = 0.6;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEntryDots(cells, pixelRatio);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderEntryDots)
        ..cells = cells
        ..pixelRatio = pixelRatio;
}

class _RenderEntryDots extends RenderBox {
  _RenderEntryDots(this._cells, this._pixelRatio);

  List<({List<Color> colors, bool inMonth})> _cells;
  set cells(List<({List<Color> colors, bool inMonth})> value) {
    if (_same(value, _cells)) return;
    _cells = value;
    markNeedsPaint();
  }

  double _pixelRatio;
  set pixelRatio(double value) {
    if (value == _pixelRatio) return;
    _pixelRatio = value;
    markNeedsPaint();
  }

  static bool _same(
    List<({List<Color> colors, bool inMonth})> a,
    List<({List<Color> colors, bool inMonth})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].inMonth != b[i].inMonth ||
          !listEquals(a[i].colors, b[i].colors)) {
        return false;
      }
    }
    return true;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    PixelSnap.settled.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    PixelSnap.settled.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final origin = PixelSnap.restingOrigin(this);
    final ratio = _pixelRatio;
    final radius = PixelSnap.radius(EntryDots.size, ratio);
    final cellWidth = size.width / 7;
    final cellHeight = size.height / 6;
    final strip = (cellWidth - 2 * EntryDots.cellMargin) * EntryDots.reach;
    final part = PixelSnap.length(strip / MonthGrid.maxDots, ratio);

    for (var i = 0; i < _cells.length; i++) {
      final cell = _cells[i];
      if (cell.colors.isEmpty) continue;
      final frameBottom = (i ~/ 7 + 1) * cellHeight - EntryDots.cellMargin;
      final y = PixelSnap.position(
        frameBottom - EntryDots.lift,
        origin.dy,
        ratio,
      );
      // The first place is put on a pixel and the rest follow at a whole
      // number of pixels each, so every gap is the same to the pixel.
      var x = PixelSnap.position(
        (i % 7 + 0.5) * cellWidth - strip / 2 + part / 2,
        origin.dx,
        ratio,
      );
      for (final color in cell.colors) {
        context.canvas.drawCircle(
          offset + Offset(x, y),
          radius,
          Paint()..color = color.withValues(alpha: cell.inMonth ? 1 : 0.4),
        );
        x += part;
      }
    }
  }
}
