import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'glyph_button.dart';
import 'strings.dart';
import 'moon_glyph.dart';
import 'appearance.dart';

/// A run of text in a reading row, optionally in a colour of its own.
typedef ReadingPart = ({String text, Color? color});

/// One line of a day reading: a system's name and what it calls the day.
/// The moon's line also carries the moon, for its glyph.
typedef ReadingLine = ({String label, List<ReadingPart> parts, Moon? moon});

extension ReadingLineText on ReadingLine {
  /// The row's value as plain text.
  String get value => parts.map((part) => part.text).join();
}

/// The traditional colours of the five elements, tuned to sit on the app's
/// dark backgrounds: wood green, fire red, earth ochre, metal pale, water
/// blue.
Map<Unsur, Color> get elementColors => Legible.map(_elementColors);

const _elementColors = <Unsur, Color>{
  Unsur.kayu: Color(0xFF7DB870),
  Unsur.api: Color(0xFFE0603F),
  Unsur.tanah: Color(0xFFCFA64E),
  Unsur.logam: Color(0xFFD9D9D2),
  Unsur.air: Color(0xFF5FA3DC),
};

/// The rows of the day reading, top to bottom. Systems that cannot place
/// [date] are left out.
List<ReadingLine> readingLines(
  CivilDate date, {
  required Duration utcOffset,
  required Strings strings,
}) {
  final weton = Weton.of(date);
  final moon = Moon.of(date, utcOffset: utcOffset);

  ReadingPart plain(String text) => (text: text, color: null);

  ReadingLine system(CalendarSystem system, List<ReadingPart> parts) =>
      (label: strings.systemLabel(system), parts: parts, moon: null);

  return [
    (
      label: strings.moon,
      parts: [
        plain(
          '${strings.moonPhase(moon.phase)} · '
          '${(moon.illumination * 100).round()}%',
        ),
      ],
      moon: moon,
    ),
    if (ChineseDate.supports(date))
      system(CalendarSystem.chinese, [
        dayElementPart(date),
        plain(' '),
        ..._chineseParts(ChineseDate.of(date), strings),
      ]),
    // The pillars of the day: for the detailed reading only.
    (
      label: strings.bazi,
      parts: baziParts(Bazi.of(date, utcOffset: utcOffset), utcOffset),
      moon: null,
    ),
    if (HijriDate.supports(date))
      system(CalendarSystem.hijri, [plain(strings.hijri(HijriDate.of(date)))]),
    if (JavaneseDate.supports(date))
      system(CalendarSystem.javanese, [plain('${JavaneseDate.of(date)}')]),
    // The season the day falls in: for the detailed reading only.
    if (PranataMangsa.supports(date))
      (
        label: strings.mangsa,
        parts: [
          plain(
            '${PranataMangsa.of(date)} · '
            '${PranataMangsa.of(date).mangsa.season.label}',
          ),
        ],
        moon: null,
      ),
    system(CalendarSystem.weton, [plain('$weton · neptu ${weton.neptu}')]),
  ];
}

/// Whether the short reading shows the Chinese date, and the shio, in
/// characters. Tapping either one flips it, and it stays that way until
/// the app is closed.
abstract final class HanziChoice {
  static final date = ValueNotifier(false);
  static final zodiac = ValueNotifier(false);
}

/// The rows of the short reading on the month screen: the moon, the
/// Chinese date and the weton. The full list is in the detailed reading.
List<ReadingLine> shortReadingLines(
  CivilDate date, {
  required Duration utcOffset,
  required Strings strings,
}) {
  final all = readingLines(date, utcOffset: utcOffset, strings: strings);
  bool isFor(ReadingLine line, CalendarSystem system) =>
      line.label == strings.systemLabel(system);
  return [
    for (final line in all)
      if (line.moon != null ||
          isFor(line, CalendarSystem.chinese) ||
          isFor(line, CalendarSystem.weton))
        line,
  ];
}

/// The Chinese date for the short reading: in characters, or in the
/// Hokkien month names Indonesia uses, whatever the app's language.
String shortChineseDate(ChineseDate date, {required bool hanzi}) => hanzi
    ? Strings.chineseHanzi(date)
    : '${date.day} ${date.monthLabel} ${date.kongziliYear}';

/// The shio for the short reading: in characters, or in words. The
/// element is coloured either way.
List<ReadingPart> shortZodiacParts(
  ChineseDate date,
  Strings strings, {
  required bool hanzi,
}) {
  final color = elementColors[date.unsur];
  ReadingPart plain(String text) => (text: text, color: null);
  if (hanzi) {
    return [
      (text: Strings.elementHanzi(date), color: color),
      plain(Strings.animalHanzi(date)),
    ];
  }
  final element = (text: strings.zodiacElement(date), color: color);
  final animal = plain(strings.zodiacAnimal(date));
  return strings.elementFirst
      ? [element, plain(' '), animal]
      : [animal, plain(' '), element];
}

/// The year, month and day pillars in characters, each marked with what
/// it is the pillar of (年 月 日). A stem is in its element's colour. On a
/// day a solar term turns the month, the term and the minute it does:
/// before then the month, and at Lichun the year, is still the old one.
List<ReadingPart> baziParts(Bazi bazi, Duration utcOffset) {
  final turns = bazi.turnsAt?.add(utcOffset);
  String two(int value) => value.toString().padLeft(2, '0');
  return [
    for (final (pillar, mark) in [
      (bazi.year, '年'),
      (bazi.month, '月'),
      (bazi.day, '日'),
    ]) ...[
      if (mark != '年') (text: ' ', color: null),
      (text: pillar.stem.hanzi, color: elementColors[pillar.stem.unsur]),
      (text: '${pillar.branch.hanzi}$mark', color: null),
    ],
    if (turns != null)
      (
        text:
            ' · ${BaziTerms.solarTerm(315 + 30.0 * ((bazi.month.branch.index - 2) % 12)).hanzi} '
            '${two(turns.hour)}:${two(turns.minute)}',
        color: null,
      ),
  ];
}

/// The element of the day, as its character in its colour. It leads the
/// Chinese row of both readings.
ReadingPart dayElementPart(CivilDate date) {
  final element = ChineseDate.dayUnsur(date);
  // In full, yin or yang: 陽金.
  return (text: Strings.dayElementHanzi(date), color: elementColors[element]);
}

/// The Chinese row: the date (in characters in English), then the shio.
List<ReadingPart> _chineseParts(ChineseDate date, Strings strings) => [
  (
    text: strings.chineseDateInHanzi
        ? Strings.chineseHanzi(date)
        : strings.chinese(date),
    color: null,
  ),
  (text: ' · ', color: null),
  ..._zodiacParts(date, strings),
];

/// The shio with its characters in brackets. The element is coloured
/// wherever it appears, in word and in character.
List<ReadingPart> _zodiacParts(ChineseDate date, Strings strings) {
  final color = elementColors[date.unsur];
  ReadingPart plain(String text) => (text: text, color: null);
  final element = (text: strings.zodiacElement(date), color: color);
  final animal = plain(strings.zodiacAnimal(date));

  return [
    if (strings.elementFirst) ...[element, plain(' '), animal],
    if (!strings.elementFirst) ...[animal, plain(' '), element],
    plain(' ('),
    (text: Strings.elementHanzi(date), color: color),
    plain('${Strings.animalHanzi(date)})'),
  ];
}

/// The day reading as plain text, for the clipboard.
String readingText(
  CivilDate date, {
  required Duration utcOffset,
  required Strings strings,
}) {
  // In the order the detailed reading lays them out: the moon, the
  // Javanese reckonings, the Hijri, and last the two in characters.
  final order = [
    strings.moon,
    strings.systemLabel(CalendarSystem.weton),
    strings.systemLabel(CalendarSystem.javanese),
    strings.mangsa,
    strings.systemLabel(CalendarSystem.hijri),
    strings.systemLabel(CalendarSystem.chinese),
    strings.bazi,
  ];
  final lines = readingLines(date, utcOffset: utcOffset, strings: strings)
    ..sort((a, b) => order.indexOf(a.label).compareTo(order.indexOf(b.label)));
  return [
    strings.gregorian(date),
    for (final line in lines) '${line.label}: ${line.value}',
  ].join('\n');
}

/// What each system makes of [year]: when its own new year falls inside
/// it, and how often the weton of [selected] comes round.
List<ReadingLine> yearLines(
  int year,
  CivilDate selected, {
  required Strings strings,
}) {
  ReadingPart plain(String text) => (text: text, color: null);
  ReadingLine system(CalendarSystem system, List<ReadingPart> parts) =>
      (label: strings.systemLabel(system), parts: parts, moon: null);

  final lines = <ReadingLine>[];
  final weton = Weton.of(selected);
  var wetonCount = 0;
  final end = CivilDate(year, 12, 31);
  for (
    var date = CivilDate(year, 1, 1);
    date.compareTo(end) <= 0;
    date = date.addDays(1)
  ) {
    if (Weton.of(date) == weton) wetonCount++;

    if (ChineseDate.supports(date)) {
      final chinese = ChineseDate.of(date);
      if (chinese.day == 1 && chinese.month == 1 && !chinese.isLeapMonth) {
        lines.add(
          system(CalendarSystem.chinese, [
            plain('${chinese.kongziliYear} '),
            ..._zodiacParts(chinese, strings),
            plain(' · ${strings.dayMonth(date)}'),
          ]),
        );
      }
    }
    if (HijriDate.supports(date)) {
      final hijri = HijriDate.of(date);
      if (hijri.day == 1 && hijri.month == HijriMonth.muharam) {
        lines.add(
          system(CalendarSystem.hijri, [
            plain('${strings.hijriYear(hijri)} · ${strings.dayMonth(date)}'),
          ]),
        );
      }
    }
    if (JavaneseDate.supports(date)) {
      final javanese = JavaneseDate.of(date);
      if (javanese.day == 1 && javanese.month == JavaneseMonth.sura) {
        lines.add(
          system(CalendarSystem.javanese, [
            plain(
              '${strings.javaneseYear(javanese)} · '
              '${strings.dayMonth(date)}',
            ),
          ]),
        );
      }
    }
  }

  // In the day reading's order: Imlek, Hijri, Javanese, then Weton.
  const order = [
    CalendarSystem.chinese,
    CalendarSystem.hijri,
    CalendarSystem.javanese,
  ];
  lines.sort(
    (a, b) => order
        .indexWhere((s) => strings.systemLabel(s) == a.label)
        .compareTo(order.indexWhere((s) => strings.systemLabel(s) == b.label)),
  );
  lines.add(
    system(CalendarSystem.weton, [
      plain('$weton · ${strings.timesInYear(wetonCount, year)}'),
    ]),
  );
  return lines;
}

/// The selected day read through the calendar systems: the Gregorian date
/// on top and one row per system below it.
///
/// In full it has a row for every system, as the detailed reading shows
/// it. The [short] form, on the month screen, keeps to the moon, the
/// Chinese date and the weton; there the Chinese date and the shio can
/// each be tapped to switch between words and characters, and a tap
/// anywhere else opens the detailed reading.
class DayReading extends StatelessWidget {
  final CivilDate date;
  final Duration utcOffset;

  /// Passed in, not read from context, so a reading that is fading out
  /// during a language change keeps its own wording until it is gone.
  final Strings strings;

  final bool short;

  /// Called when the short reading is tapped.
  final VoidCallback? onExpand;

  /// The colour of the bell shown opposite the date when the day has
  /// reminders; null when it has none.
  final Color? bell;

  const DayReading({
    super.key,
    required this.date,
    required this.utcOffset,
    required this.strings,
    this.short = false,
    this.onExpand,
    this.bell,
  });

  @override
  Widget build(BuildContext context) {
    if (!short) {
      return ReadingPanel(
        title: strings.gregorian(date),
        lines: readingLines(date, utcOffset: utcOffset, strings: strings),
      );
    }
    final chineseLabel = strings.systemLabel(CalendarSystem.chinese);
    return ReadingPanel(
      title: strings.gregorian(date),
      lines: shortReadingLines(date, utcOffset: utcOffset, strings: strings),
      onTap: onExpand,
      bell: bell,
      valueOf: (line, style) => line.label == chineseLabel
          ? _ShortChinese(
              civil: date,
              date: ChineseDate.of(date),
              strings: strings,
              style: style,
            )
          : null,
    );
  }
}

/// The Chinese row of the short reading: the date and the shio, each of
/// which flips between words and characters when tapped.
class _ShortChinese extends StatelessWidget {
  final CivilDate civil;
  final ChineseDate date;
  final Strings strings;
  final TextStyle style;

  const _ShortChinese({
    required this.civil,
    required this.date,
    required this.strings,
    required this.style,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([HanziChoice.date, HanziChoice.zodiac]),
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The element of the day leads the row.
        Text(
          dayElementPart(civil).text,
          key: const ValueKey('chinese-day-element'),
          style: style.copyWith(color: dayElementPart(civil).color),
        ),
        Text(' ', style: style),
        Flexible(
          child: _flip(
            'chinese-date',
            HanziChoice.date,
            Text(
              shortChineseDate(date, hanzi: HanziChoice.date.value),
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ),
        ),
        Text(' · ', style: style),
        _flip(
          'chinese-zodiac',
          HanziChoice.zodiac,
          Text.rich(
            TextSpan(
              children: [
                for (final part in shortZodiacParts(
                  date,
                  strings,
                  hanzi: HanziChoice.zodiac.value,
                ))
                  TextSpan(
                    text: part.text,
                    style: part.color == null
                        ? null
                        : TextStyle(color: part.color),
                  ),
              ],
            ),
            style: style,
          ),
        ),
      ],
    ),
  );

  // Taller than the text, so it is easy to hit; a tap here does not reach
  // the reading behind it.
  Widget _flip(String name, ValueNotifier<bool> choice, Widget child) =>
      GestureDetector(
        key: ValueKey(name),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          choice.value = !choice.value;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: child,
        ),
      );
}

/// A whole year read through every system: the year on top, then when each
/// system's new year falls in it.
class YearReading extends StatelessWidget {
  final int year;
  final CivilDate selected;
  final Strings strings;

  const YearReading({
    super.key,
    required this.year,
    required this.selected,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) => ReadingPanel(
    title: '$year · ${strings.newYear}',
    lines: yearLines(year, selected, strings: strings),
  );
}

/// A header and a scrollable list of reading rows.
class ReadingPanel extends StatelessWidget {
  final String title;
  final List<ReadingLine> lines;

  /// Called when the panel is tapped anywhere that does not take the tap
  /// itself.
  final VoidCallback? onTap;

  /// Draws a line's value in its own way; null, or a null result, leaves
  /// it as plain text.
  final Widget? Function(ReadingLine line, TextStyle style)? valueOf;

  /// A bell in this colour at the far end of the title's line, as tall
  /// as the line; null for none.
  final Color? bell;

  /// More under the rows, in the same scroll: what an entry being read
  /// adds to its day (its time, place, category and tags).
  final List<Widget> after;

  const ReadingPanel({
    super.key,
    required this.title,
    required this.lines,
    this.onTap,
    this.valueOf,
    this.bell,
    this.after = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final valueStyle = theme.type.body.copyWith(
      color: theme.colors.textPrimary,
    );

    Widget value(ReadingLine line) =>
        valueOf?.call(line, valueStyle) ??
        Text.rich(
          TextSpan(
            children: [
              for (final part in line.parts)
                TextSpan(
                  text: part.text,
                  style: part.color == null
                      ? null
                      : TextStyle(color: part.color),
                ),
            ],
          ),
          textAlign: TextAlign.end,
          style: valueStyle,
        );

    final panel = _panel(
      theme,
      value,
      MediaQuery.textScalerOf(context)
          .scale(theme.type.title.fontSize! * theme.type.title.height!),
    );
    if (onTap == null) return panel;
    return GestureDetector(
      key: const ValueKey('expand-reading'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: panel,
    );
  }

  Widget _panel(
    SmThemeData theme,
    Widget Function(ReadingLine) value,
    double titleLine,
  ) {
    final spacing = theme.spacing;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.type.title.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
              // The day has reminders: a bell, exactly as tall as the
              // date's own line.
              if (bell != null)
                GlyphMark(
                  key: const ValueKey('reading-bell'),
                  glyph: Glyph.reminder,
                  size: titleLine,
                  color: bell!,
                ),
            ],
          ),
          SizedBox(height: spacing.md - spacing.xs),
          for (final line in lines)
            ReadingRow(
              label: line.label.toUpperCase(),
              child: line.moon == null
                  ? value(line)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoonGlyph(
                          moon: line.moon!,
                          size: 13,
                          color: theme.colors.textPrimary,
                        ),
                        SizedBox(width: spacing.sm),
                        Flexible(child: value(line)),
                      ],
                    ),
            ),
          ...after,
        ],
      ),
    );
  }
}

/// One system's line in the day reading: its name, then its value.
class ReadingRow extends StatelessWidget {
  final String label;
  final Widget child;

  const ReadingRow({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: theme.type.caption.copyWith(
              color: theme.colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}
