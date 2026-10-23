import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'pixel_snap.dart';
import 'strings.dart';
import 'system_months.dart';

/// A whole year as its months in mini, three across: the twelve of a
/// Gregorian year, or on the calendar under the Chinese, Hijri or
/// Javanese system that system's year, its twelve months or the Chinese
/// thirteen, each numbered as it counts (owner, 21 October 2026).
///
/// - Weton: every day sharing the selected day's weton is a filled pill.
///
/// Beside each month's name, from the right edge leftwards, are up to
/// [maxDots] entry dots: one per category with entries in that month.
///
/// Drawn in one pass on a canvas; five hundred day widgets would be far
/// too heavy to zoom and swipe.
class YearGrid extends StatefulWidget {
  /// The months of the year, in order.
  final List<SystemMonth> months;

  /// Their names, as the mini-months are headed.
  final List<String> monthLabels;

  /// The Gregorian year its first month begins in.
  int get year => months.first.first.year;

  /// The twelve months of a Gregorian [year], named by their first three
  /// letters in [strings]' language.
  static List<SystemMonth> gregorian(int year) => [
    for (var m = 1; m <= 12; m++)
      SystemMonth(CivilDate(year, m, 1), CivilDate.daysInMonth(year, m)),
  ];
  final CalendarSystem system;
  final CivilDate today;
  final CivilDate selected;
  final Strings strings;
  final ValueChanged<int> onTapMonth;

  /// The colours of a month's (from 1) entry dots, earliest entry first.
  /// Only the first [maxDots] are shown.
  final List<Color> Function(int month)? dotsOf;

  static const maxDots = 8;

  const YearGrid({
    super.key,
    required this.months,
    required this.monthLabels,
    required this.system,
    required this.today,
    required this.selected,
    required this.strings,
    required this.onTapMonth,
    this.dotsOf,
  });

  static const columns = 3;

  /// How many rows [count] months take: four, or five for thirteen.
  static int rowsFor(int count) => (count + columns - 1) ~/ columns;

  /// Where the [month]th (from 1) of [count] sits in a year grid of
  /// [size].
  static Rect slotOf(int month, Size size, [int count = 12]) {
    final width = size.width / columns;
    final height = size.height / rowsFor(count);
    return Rect.fromLTWH(
      (month - 1) % columns * width,
      (month - 1) ~/ columns * height,
      width,
      height,
    );
  }

  /// The month (from 1) of [count] at [position] in a year grid of [size].
  static int monthAt(Offset position, Size size, [int count = 12]) {
    final rows = rowsFor(count);
    final column = (position.dx / (size.width / columns)).floor().clamp(
      0,
      columns - 1,
    );
    final row = (position.dy / (size.height / rows)).floor().clamp(0, rows - 1);
    return (row * columns + column + 1).clamp(1, count);
  }

  @override
  State<YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<YearGrid> {
  final _canvas = GlobalKey();

  // The mini-month under the finger. It glows, and stays lit while the
  // view zooms in to it.
  int? _pressed;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => setState(
            () => _pressed = YearGrid.monthAt(
              details.localPosition,
              size,
              widget.months.length,
            ),
          ),
          onTapCancel: () => setState(() => _pressed = null),
          onTapUp: (details) => widget.onTapMonth(
            YearGrid.monthAt(details.localPosition, size, widget.months.length),
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              key: _canvas,
              size: size,
              painter: _YearPainter(
                months: widget.months,
                system: widget.system,
                today: widget.today,
                selected: widget.selected,
                pressed: _pressed,
                pixelRatio: MediaQuery.devicePixelRatioOf(context),
                // Read while painting, when the canvas knows where it is.
                origin: () {
                  final box = _canvas.currentContext?.findRenderObject();
                  return box is RenderBox
                      ? PixelSnap.restingOrigin(box)
                      : Offset.zero;
                },
                dots: [
                  for (var month = 1; month <= widget.months.length; month++)
                    (widget.dotsOf?.call(month) ?? const [])
                        .take(YearGrid.maxDots)
                        .toList(),
                ],
                monthLabels: [
                  for (final name in widget.monthLabels) name.toUpperCase(),
                ],
                colors: theme.colors,
                labelStyle: theme.type.caption.copyWith(letterSpacing: 1.2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _YearPainter extends CustomPainter {
  final List<SystemMonth> months;
  final CalendarSystem system;
  final CivilDate today;
  final CivilDate selected;
  final int? pressed;

  /// A list of dot colours for each month, the first month first.
  final List<List<Color>> dots;

  /// For putting the dots on whole pixels; see [PixelSnap].
  final double pixelRatio;
  final Offset Function() origin;
  final List<String> monthLabels;
  final SmColors colors;
  final TextStyle labelStyle;

  _YearPainter({
    required this.months,
    required this.system,
    required this.today,
    required this.selected,
    required this.pressed,
    required this.dots,
    required this.pixelRatio,
    required this.origin,
    required this.monthLabels,
    required this.colors,
    required this.labelStyle,
  }) : super(repaint: PixelSnap.settled);

  static const _slotPadding = 7.0;
  static const _labelHeight = 18.0;
  // The row of entry dots over the month's name.
  static const _dotRow = 8.0;
  static const _numberSize = 7.0;
  static const _dotSize = 4.0;
  static const _dotGap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final wetonOfSelected = Weton.of(selected);
    final corner = origin();
    final dotRadius = PixelSnap.radius(_dotSize, pixelRatio);
    final dotStep = PixelSnap.length(_dotSize + _dotGap, pixelRatio);
    final count = months.length;
    for (var month = 1; month <= count; month++) {
      final span = months[month - 1];
      if (month == pressed) {
        // The whole mini-month lights up: a soft halo, a tint and a rim.
        final glow = RRect.fromRectAndRadius(
          YearGrid.slotOf(month, size, count).deflate(2),
          const Radius.circular(12),
        );
        canvas.drawRRect(
          glow,
          Paint()
            ..color = colors.accent.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
        );
        canvas.drawRRect(
          glow,
          Paint()..color = colors.accent.withValues(alpha: 0.14),
        );
        canvas.drawRRect(
          glow,
          Paint()
            ..color = colors.accent.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      final slot = YearGrid.slotOf(month, size, count).deflate(_slotPadding);
      final isThisMonth = span.contains(today);
      _text(
        canvas,
        monthLabels[month - 1],
        labelStyle.copyWith(
          color: isThisMonth ? colors.accent : colors.textSecondary,
        ),
        Offset(slot.left + 2, slot.top + _dotRow),
        centred: false,
        maxWidth: slot.width - 4,
      );

      // The month's entry dots, in a row of their own over its name, from
      // its left edge (owner, 22 October 2026: level with the name, at the
      // right, they ran into a long one, a Hijri month's most of all).
      final monthDots = dots[month - 1];
      final firstX = PixelSnap.position(
        slot.left + 2 + _dotSize / 2,
        corner.dx,
        pixelRatio,
      );
      final dotY = PixelSnap.position(
        slot.top + _dotSize / 2,
        corner.dy,
        pixelRatio,
      );
      for (var i = 0; i < monthDots.length; i++) {
        canvas.drawCircle(
          Offset(firstX + i * dotStep, dotY),
          dotRadius,
          Paint()..color = monthDots[i],
        );
      }

      final grid = Rect.fromLTRB(
        slot.left,
        slot.top + _dotRow + _labelHeight,
        slot.right,
        slot.bottom,
      );
      final cell = Size(grid.width / 7, grid.height / 6);
      final first = span.first;
      final lead = Weekday.of(first).index;

      for (var day = 1; day <= span.length; day++) {
        final date = first.addDays(day - 1);
        final index = lead + day - 1;
        final rect = Rect.fromLTWH(
          grid.left + index % 7 * cell.width,
          grid.top + index ~/ 7 * cell.height,
          cell.width,
          cell.height,
        );
        var numberColor = colors.textPrimary.withValues(alpha: 0.82);

        // Marks are pills filling the cell. The numbers are set small
        // enough that two digits sit inside one with room to spare.
        final pill = RRect.fromRectAndRadius(
          rect.deflate(0.75),
          Radius.circular(rect.height / 2),
        );
        if (date == selected) {
          canvas.drawRRect(pill, Paint()..color = colors.surfaceRaised);
        }
        if (system == CalendarSystem.weton &&
            Weton.of(date) == wetonOfSelected) {
          canvas.drawRRect(pill, Paint()..color = colors.accent);
          numberColor = colors.background;
        }
        if (date == today) {
          canvas.drawRRect(
            pill,
            Paint()
              ..color = colors.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }

        _text(
          canvas,
          '$day',
          TextStyle(
            fontFamily: SmType.family,
            package: SmType.package,
            fontSize: _numberSize,
            height: 1,
            color: numberColor,
          ),
          rect.center,
          centred: true,
        );
      }
    }
  }

  // Laid-out text is kept: the same few dozen strings are drawn hundreds
  // of times a frame while zooming.
  static final _laidOut = <String, TextPainter>{};

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    required bool centred,
    double? maxWidth,
  }) {
    final key =
        '$text|${style.color!.toARGB32()}|${style.fontSize}|'
        '${style.letterSpacing}';
    if (_laidOut.length > 600) _laidOut.clear();
    final painter = _laidOut[key] ??= TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    // Wider than its room, it is drawn smaller to fit, from its left.
    if (maxWidth != null && painter.width > maxWidth && !centred) {
      final k = maxWidth / painter.width;
      canvas.save();
      canvas.translate(at.dx, at.dy + painter.height * (1 - k) / 2);
      canvas.scale(k);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
      return;
    }
    painter.paint(canvas, centred ? at - painter.size.center(Offset.zero) : at);
  }

  @override
  bool shouldRepaint(_YearPainter oldDelegate) =>
      !listEquals(oldDelegate.months, months) ||
      oldDelegate.system != system ||
      oldDelegate.today != today ||
      oldDelegate.selected != selected ||
      oldDelegate.pressed != pressed ||
      !listEquals(
        oldDelegate.dots.expand((d) => d).toList(),
        dots.expand((d) => d).toList(),
      ) ||
      !listEquals(
        [for (final d in oldDelegate.dots) d.length],
        [for (final d in dots) d.length],
      ) ||
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.monthLabels, monthLabels);
}
