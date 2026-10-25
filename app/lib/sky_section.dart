import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'day_reading.dart';
import 'journal/geo.dart';
import 'sky_place.dart';
import 'strings.dart';

/// The sky of a day, under its reading in detailed mode: the sun's path
/// with sunrise and sunset, the moon's with moonrise and moonset, how
/// much of the moon is lit, and when it is next full and next new.
///
/// The paths and their times need a place, the [SkyPlace]. Until one is
/// set they are left out, and a line says how to set it. What does not
/// depend on place (the lit fraction, the coming phases) is always shown.
class SkySection extends StatefulWidget {
  final CivilDate date;
  final Duration utcOffset;
  final Strings strings;

  /// Now, in minutes after midnight, if [date] is today: marked on the
  /// paths.
  final int? nowMinute;

  const SkySection({
    super.key,
    required this.date,
    required this.utcOffset,
    required this.strings,
    this.nowMinute,
  });

  @override
  State<SkySection> createState() => _SkySectionState();
}

class _SkySectionState extends State<SkySection> {
  bool _finding = false;
  String? _problem;

  Future<void> _setPlace() async {
    if (_finding) return;
    HapticFeedback.selectionClick();
    setState(() {
      _finding = true;
      _problem = null;
    });
    final strings = widget.strings;
    try {
      final fix = await Locator.current.find();
      SkyPlace.current.value = SkyPlace.rounded(fix.latitude, fix.longitude);
      if (mounted) setState(() => _finding = false);
    } on LocateFailed catch (failed) {
      if (!mounted) return;
      setState(() {
        _finding = false;
        _problem = switch (failed.problem) {
          LocateProblem.denied => strings.placeDenied,
          LocateProblem.off => strings.placeOff,
          LocateProblem.timeout => strings.placeTimeout,
          LocateProblem.sky => strings.placeNeedsSky,
          LocateProblem.unavailable => strings.placeUnavailable,
          LocateProblem.cancelled => null,
        };
      });
    }
  }

  @override
  void dispose() {
    if (_finding) Locator.current.cancel();
    super.dispose();
  }

  static String _clock(int? minute, Strings strings) => minute == null
      ? strings.notThatDay
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:'
            '${(minute % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = widget.strings;
    final date = widget.date;
    final offset = widget.utcOffset;
    final valueStyle = theme.type.body.copyWith(color: colors.textPrimary);

    Widget row(String label, String value, {Key? key}) => ReadingRow(
      key: key,
      label: label.toUpperCase(),
      child: Text(value, textAlign: TextAlign.end, style: valueStyle),
    );

    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: spacing.lg, bottom: spacing.xs),
      child: Text(
        text,
        style: theme.type.title.copyWith(
          fontSize: 15,
          color: colors.textPrimary,
        ),
      ),
    );

    // A coming phase: its day, and how far off that is.
    String phase(double elongation) {
      final at = Sky.nextPhase(
        date,
        utcOffset: offset,
        elongation: elongation,
      ).add(offset);
      final day = CivilDate(at.year, at.month, at.day);
      return '${strings.gregorian(day)} · '
          '${strings.inDays(day.dayNumber - date.dayNumber)}';
    }

    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) {
        final sun = place == null
            ? null
            : Sky.sun(
                date,
                latitude: place.latitude,
                longitude: place.longitude,
                utcOffset: offset,
              );
        final moon = place == null
            ? null
            : Sky.moon(
                date,
                latitude: place.latitude,
                longitude: place.longitude,
                utcOffset: offset,
              );

        return Padding(
          key: const ValueKey('sky-section'),
          padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sun != null) ...[
                heading(strings.sun),
                SkyChart(
                  key: const ValueKey('sun-chart'),
                  path: sun,
                  color: colors.accent,
                  line: colors.outline,
                  background: colors.surface,
                  nowMinute: widget.nowMinute,
                ),
                row(
                  strings.sunrise,
                  _clock(sun.rise, strings),
                  key: const ValueKey('sunrise'),
                ),
                row(
                  strings.sunset,
                  _clock(sun.set, strings),
                  key: const ValueKey('sunset'),
                ),
                if (sun.rise != null && sun.set != null)
                  row(
                    strings.daylight,
                    strings.hoursMinutes(sun.set! - sun.rise!),
                    key: const ValueKey('daylight'),
                  ),
              ],
              heading(strings.moonHeading),
              if (moon != null) ...[
                SkyChart(
                  key: const ValueKey('moon-chart'),
                  path: moon,
                  color: colors.textPrimary,
                  line: colors.outline,
                  background: colors.surface,
                  nowMinute: widget.nowMinute,
                ),
                row(
                  strings.moonrise,
                  _clock(moon.rise, strings),
                  key: const ValueKey('moonrise'),
                ),
                row(
                  strings.moonset,
                  _clock(moon.set, strings),
                  key: const ValueKey('moonset'),
                ),
              ],
              // How much is lit is said at the reading's head.
              row(
                strings.nextFullMoon,
                phase(180),
                key: const ValueKey('next-full-moon'),
              ),
              row(
                strings.nextNewMoon,
                phase(0),
                key: const ValueKey('next-new-moon'),
              ),
              // Which place the times are for, or how to give one.
              GestureDetector(
                key: const ValueKey('sky-place'),
                behavior: HitTestBehavior.opaque,
                onTap: _setPlace,
                child: Padding(
                  padding: EdgeInsets.only(top: spacing.md),
                  child: Text(
                    _finding
                        ? strings.skyFinding
                        : _problem ??
                              (place == null
                                  ? strings.skyNeedsPlace
                                  : strings.skyPlace(SkyPlace.label(place))),
                    style: theme.type.caption.copyWith(
                      color: place == null && !_finding
                          ? colors.accent
                          : colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A body's path over a day, drawn as its height against the hours: a
/// curve that crosses a level line, the horizon, where it rises and where
/// it sets. The part above the horizon is drawn strong and filled under;
/// the part below is faint. A dot marks each crossing, and now, if the
/// day is today.
class SkyChart extends StatelessWidget {
  final SkyPath path;
  final Color color;
  final Color line;
  final Color background;
  final int? nowMinute;

  const SkyChart({
    super.key,
    required this.path,
    required this.color,
    required this.line,
    required this.background,
    this.nowMinute,
  });

  static const height = 84.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: _SkyChartPainter(path, color, line, background, nowMinute),
      size: Size.infinite,
    ),
  );
}

class _SkyChartPainter extends CustomPainter {
  final SkyPath path;
  final Color color;
  final Color line;
  final Color background;
  final int? nowMinute;

  const _SkyChartPainter(
    this.path,
    this.color,
    this.line,
    this.background,
    this.nowMinute,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // The horizon sits two thirds of the way down. Above it there is room
    // for the highest the body stands that day; below, the curve runs off
    // the bottom.
    final horizon = (size.height * 0.66).roundToDouble();
    final top = math.max(path.highest, 20.0);
    final scale = (horizon - 8) / top;
    Offset at(double minute, double altitude) =>
        Offset(size.width * minute / 1440, horizon - altitude * scale);

    final curve = Path();
    for (var i = 0; i < path.altitudes.length; i++) {
      final point = at(i * SkyPath.step.toDouble(), path.altitudes[i]);
      i == 0
          ? curve.moveTo(point.dx, point.dy)
          : curve.lineTo(point.dx, point.dy);
    }
    final above = Rect.fromLTWH(0, 0, size.width, horizon);
    final frame = Offset.zero & size;

    canvas
      ..save()
      ..clipRect(frame)
      // Below the horizon: faint.
      ..drawPath(
        curve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.25),
      )
      ..restore()
      ..save()
      ..clipRect(above)
      // Above it: filled under, and drawn strong.
      ..drawPath(
        Path.from(curve)
          ..lineTo(size.width, horizon)
          ..lineTo(0, horizon)
          ..close(),
        Paint()..color = color.withValues(alpha: 0.12),
      )
      ..drawPath(
        curve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      )
      ..restore()
      ..drawLine(
        Offset(0, horizon),
        Offset(size.width, horizon),
        Paint()
          ..strokeWidth = 1
          ..color = line,
      );

    for (final crossing in [path.rise, path.set]) {
      if (crossing == null) continue;
      final point = Offset(size.width * crossing / 1440, horizon);
      canvas
        ..drawCircle(point, 4, Paint()..color = background)
        ..drawCircle(
          point,
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color,
        );
    }
    final now = nowMinute;
    if (now != null) {
      final point = at(now.toDouble(), path.altitudeAt(now));
      if (frame.contains(point)) {
        canvas.drawCircle(point, 4.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_SkyChartPainter old) =>
      old.path != path ||
      old.color != color ||
      old.line != line ||
      old.background != background ||
      old.nowMinute != nowMinute;
}
