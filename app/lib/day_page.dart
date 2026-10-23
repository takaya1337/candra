import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'day_reading.dart';
import 'moon_glyph.dart';
import 'parts.dart';
import 'strings.dart';
import 'system_months.dart';

/// One day as a sheet of a tear-off calendar: the Gregorian date very
/// large at the centre, and every other system's name for the same day
/// in the corners round it.
///
///  * Head: the month and the year.
///  * Corners: Javanese and the weton above the number, Hijri and
///    Chinese below it. The system the calendar is set to has its name in
///    the accent colour. A system that cannot place the day is left out.
///  * Centre: the day of the month, the weekday under it, and a dot for
///    each category with a reminder that day.
///
/// Under the Chinese, Hijri and Javanese systems the sheet is that
/// system's (owner, 21 October 2026): the head its month and year, the
/// number its day, under it its month (the Chinese with the day's
/// element, in its colour), and the Gregorian date in that system's
/// corner. Under the weton the weekday has the pasaran and the neptu
/// after it.
///  * Foot: the moon, and the Chinese year's animal.
class DayPage extends StatelessWidget {
  final CivilDate date;
  final CivilDate today;
  final CalendarSystem system;
  final Duration utcOffset;
  final Strings strings;

  /// The colours of the day's reminders, as the month grid dots them.
  final List<Color> dots;

  const DayPage({
    super.key,
    required this.date,
    required this.today,
    required this.system,
    required this.utcOffset,
    required this.strings,
    this.dots = const [],
  });

  /// How tall the figures of the app's typeface are, as a share of its
  /// size: JetBrains Mono's capitals and figures stand 730 units in
  /// 1000.
  static const figureHeight = 0.73;

  /// The room above the number and below it, the same both ways.
  static const numberGap = 14.0;

  /// The room inside the sheet on a phone held upright, the layout a
  /// tablet on its side shows scaled up whole (owner, 19 October 2026:
  /// "the phone's proportion scaled properly to the iPad").
  ///
  /// Measured on the Pixel 4 XL, 412 x 869 points: the sheet is 380 x 484
  /// and the room inside its border and padding 330 x 362. In it, top to
  /// foot: the corners above, 50; the gap, 14; the number's room, 184;
  /// the gap, 14; the weekday, 26 (20 points); the dots, 24; the corners
  /// below, 50. A day of two figures fills the width, so on the phone the
  /// number is 330 x 120.5, centred in its room: 45.7 over the weekday.
  /// (The iPhone 17 Pro Max, 440 x 956: room 358 x 381, number 358 x 131;
  /// the same shape within 5%.)
  ///
  /// On the iPad mini on its side the room is 650 x 550. Scaled by the
  /// width, 650 / 330 = 1.97, the phone's layout would stand 362 x 1.97 =
  /// 713 high, a third more than there is; so the height governs, 550 /
  /// 362 = 1.52, the smaller of the two ratios, the largest at which the
  /// whole of the phone's layout fits. Everything inside is that much
  /// larger: the number 501 x 183, centred across the wider sheet; the
  /// weekday 30.4 points, 69.5 under it; the gaps 21.3; the corners' text
  /// 1.52 times its size, still at the sheet's corners.
  ///
  /// Upright (19 October 2026) the same: on the iPad mini the room is
  /// about 662 wide, twice the phone's, and the height again governs (the
  /// lower panel being the phone's scaled, see [FourParts.phoneScale]).
  static const phoneRoom = Size(330, 362);

  // Sundays are printed red, as on every calendar on an Indonesian wall.
  static const sunday = Color(0xFFE0603F);

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final weton = Weton.of(date);
    final moon = Moon.of(date, utcOffset: utcOffset);
    final isSunday = weton.weekday == Weekday.values.last;
    final isToday = date == today;
    final ink = isSunday ? sunday : colors.textPrimary;
    // On a tablet, on its side or upright, the phone's layout scaled.
    final tall =
        FourParts.tallPanel(context) || FourParts.tabletUpright(context);

    final hijri = HijriDate.supports(date) ? HijriDate.of(date) : null;
    final chinese = ChineseDate.supports(date) ? ChineseDate.of(date) : null;
    final javanese = JavaneseDate.supports(date) ? JavaneseDate.of(date) : null;
    // Whether the sheet is the system's own, and what it says at its
    // centre.
    final calendar = SystemCalendar.of(system);
    final shifted =
        calendar.shifts &&
        switch (system) {
          CalendarSystem.chinese => chinese != null,
          CalendarSystem.hijri => hijri != null,
          _ => javanese != null,
        };
    final month = shifted ? calendar.monthOf(date) : null;

    // How much larger than on a phone everything inside the sheet is: 1
    // on phones; on a tablet, given by the room once it is known.
    var k = 1.0;

    Widget corner(
      CalendarSystem of,
      String first,
      String second, {
      required bool end,
      Color? secondColor,
    }) => Column(
      key: ValueKey('day-page-${of.name}'),
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.systemLabel(of).toUpperCase(),
          style: theme.type.caption.copyWith(
            color: of == system ? colors.accent : colors.textFaint,
            fontSize: theme.type.caption.fontSize! * k,
            letterSpacing: 1.2 * k,
          ),
        ),
        SizedBox(height: spacing.xs * k),
        Text(
          first,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: theme.type.body.copyWith(
            color: colors.textPrimary,
            fontSize: theme.type.body.fontSize! * k,
          ),
        ),
        Text(
          second,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: theme.type.label.copyWith(
            color: secondColor ?? colors.textSecondary,
            fontSize: theme.type.label.fontSize! * k,
          ),
        ),
      ],
    );

    // In the place of the system the sheet is in: the Gregorian date.
    Widget gregorian({required bool end}) => corner(
      CalendarSystem.gregorian,
      '${date.day} ${strings.monthNames[date.month - 1]}',
      '${date.year}',
      end: end,
    );

    // The four calendars of the corners; the system the sheet is in has
    // the Gregorian date in its place.
    Widget? javaneseCorner({required bool end}) =>
        shifted && system == CalendarSystem.javanese
        ? gregorian(end: end)
        : javanese == null
        ? null
        : corner(
            CalendarSystem.javanese,
            '${javanese.day} ${javanese.month.label}',
            strings.javaneseYear(javanese),
            end: end,
          );
    Widget wetonCorner({required bool end}) => corner(
      CalendarSystem.weton,
      '$weton',
      'neptu ${weton.neptu}',
      end: end,
    );
    Widget? hijriCorner({required bool end}) =>
        shifted && system == CalendarSystem.hijri
        ? gregorian(end: end)
        : hijri == null
        ? null
        : corner(
            CalendarSystem.hijri,
            '${hijri.day} ${strings.hijriMonth(hijri.month)}',
            strings.hijriYear(hijri),
            end: end,
          );
    Widget? chineseCorner({required bool end}) =>
        shifted && system == CalendarSystem.chinese
        ? gregorian(end: end)
        : chinese == null
        ? null
        : corner(
            CalendarSystem.chinese,
            '${chinese.day} ${chinese.monthLabel}',
            // Under the day, its element in full, yin or yang, in its own
            // colour.
            Strings.dayElementHanzi(date),
            secondColor: elementColors[ChineseDate.dayUnsur(date)],
            end: end,
          );

    Widget corners(Widget? left, Widget? right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left ?? const SizedBox.shrink()),
        SizedBox(width: spacing.md * k),
        Expanded(
          child: Align(
            alignment: Alignment.topRight,
            child: right ?? const SizedBox.shrink(),
          ),
        ),
      ],
    );

    final head = theme.type.title.copyWith(
      color: system == CalendarSystem.gregorian || shifted
          ? colors.accent
          : colors.textSecondary,
      letterSpacing: 2,
    );

    return Container(
      key: ValueKey('day-page-${date.dayNumber}'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: isToday ? colors.accent : colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.lg),
      ),
      child: Column(
        children: [
          // The head of the sheet, where it was bound to the block.
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.md,
              spacing.lg,
              spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (month == null
                            ? strings.monthNames[date.month - 1]
                            : calendar.monthName(month, strings))
                        .toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: head,
                  ),
                ),
                Text(
                  month == null
                      ? '${date.year}'
                      : calendar.yearName(date, strings),
                  style: head,
                ),
              ],
            ),
          ),
          Container(height: 1, color: colors.outline),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.md,
                spacing.lg,
                spacing.md,
              ),
              child: LayoutBuilder(
                builder: (context, room) {
                  // On a tablet, the phone's layout scaled to fit the
                  // room whole ([phoneRoom]), on its side and upright.
                  if (tall) {
                    k = math.min(
                      room.maxWidth / phoneRoom.width,
                      room.maxHeight / phoneRoom.height,
                    );
                  }
                  final number = FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      '${shifted ? calendar.dayOf(date) : date.day}',
                      key: const ValueKey('day-page-number'),
                      style: theme.type.display.copyWith(
                        fontFamily: SmType.figureFamily,
                        package: SmType.package,
                        fontSize: 200,
                        // The line is cut down to the figures
                        // themselves, top to foot, with nothing of the
                        // typeface's own room above or below them:
                        // so the gaps measured from it are the gaps
                        // seen.
                        height: figureHeight,
                        leadingDistribution: TextLeadingDistribution.even,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  );
                  // The weekday; under the weton with its pasaran and
                  // neptu; under the Chinese with the day's element.
                  final weekday = FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          // The weekday, under every system; under the
                          // weton in Indonesian whatever the language,
                          // as a weton is named (owner, 21 October
                          // 2026).
                          TextSpan(
                            text:
                                (system == CalendarSystem.weton
                                        ? weton.weekday.label
                                        : strings.weekdayName(weton.weekday))
                                    .toUpperCase(),
                          ),
                          if (system == CalendarSystem.weton)
                            TextSpan(
                              text:
                                  ' · ${weton.pasaran.label.toUpperCase()}'
                                  ' · ${weton.neptu}',
                            ),
                          if (system == CalendarSystem.chinese &&
                              chinese != null)
                            TextSpan(
                              text: ' · ${Strings.dayElementHanzi(date)}',
                              style: TextStyle(
                                color:
                                    elementColors[ChineseDate.dayUnsur(date)],
                                letterSpacing: 2 * k,
                              ),
                            ),
                        ],
                      ),
                      key: const ValueKey('day-page-weekday'),
                      maxLines: 1,
                      style: theme.type.title.copyWith(
                        fontFamily: SmType.figureFamily,
                        package: SmType.package,
                        fontSize: theme.type.title.fontSize! * k,
                        color: ink,
                        letterSpacing: 6 * k,
                      ),
                    ),
                  );
                  // A dot for each category with a reminder that day; the
                  // row keeps its height when there are none.
                  final marks = SizedBox(
                    height: (spacing.md + spacing.sm) * k,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final color in dots)
                          Container(
                            width: 6 * k,
                            height: 6 * k,
                            margin: EdgeInsets.symmetric(horizontal: 3 * k),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                  // The number has whatever room is left, less the same
                  // gap above it as below.
                  final figure = Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: numberGap * k),
                      // On the tablet no wider than the phone's room,
                      // scaled: the sheet is wider in proportion.
                      child: tall
                          ? Center(
                              child: SizedBox(
                                width: phoneRoom.width * k,
                                child: number,
                              ),
                            )
                          : number,
                    ),
                  );
                  // A phone on its side: the room is wide and short, too
                  // short for the corners above and below the number. The
                  // four calendars stand down the left, in the order they
                  // are read upright, and the number, weekday and dots on
                  // the right (22 October 2026, the calendars moved to the
                  // left at the owner's word the same day).
                  if (!tall && room.maxWidth > room.maxHeight * 1.4) {
                    final calendars = [
                      javaneseCorner(end: false),
                      wetonCorner(end: false),
                      hijriCorner(end: false),
                      chineseCorner(end: false),
                    ].nonNulls.toList();
                    return Row(
                      key: const ValueKey('day-page-sideways'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // A gap between each, the whole made smaller if
                        // the room is shorter than that.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (i, c) in calendars.indexed) ...[
                                if (i > 0) SizedBox(height: spacing.md),
                                c,
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: spacing.lg),
                        Expanded(
                          child: Column(children: [figure, weekday, marks]),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      // Above the number the Javanese date and the weton,
                      // below it the Hijri and the Chinese (owner, 20
                      // October 2026).
                      corners(
                        javaneseCorner(end: false),
                        wetonCorner(end: true),
                      ),
                      figure,
                      weekday,
                      marks,
                      corners(
                        hijriCorner(end: false),
                        chineseCorner(end: true),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(height: 1, color: colors.outline),
          // The foot: the moon, and the Chinese year.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.sm + 2,
            ),
            child: Row(
              children: [
                MoonGlyph(moon: moon, size: 13, color: colors.textPrimary),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    '${strings.moonPhase(moon.phase)} · '
                    '${(moon.illumination * 100).round()}%',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (chinese != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final part in shortZodiacParts(
                          chinese,
                          strings,
                          hanzi: false,
                        ))
                          TextSpan(
                            text: part.text,
                            style: part.color == null
                                ? null
                                : TextStyle(color: part.color),
                          ),
                      ],
                    ),
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
