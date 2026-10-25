import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'day_reading.dart';
import 'moon_glyph.dart';
import 'strings.dart';

/// The day in full, for the detailed reading (owner, 26 October 2026: "as
/// it is, everything looks cluttered as if we're dumping everything to
/// the user instead of presenting").
///
///  * At the head, the moon drawing itself ([TracedMoon]), and beside it
///    the date and the moon said in full: its phase, how much is lit.
///  * Then the calendars in groups, a hairline between them, each value
///    in two tiers, what matters first and the rest faint under it: the
///    Javanese reckonings (weton, the Javanese date, the mangsa); the
///    Hijri; and last the two in characters, the Chinese date and the
///    bazi's three pillars, each captioned with what it is the pillar of.
///
/// What it says is what [readingLines] says, laid out to be read.
class DayDetail extends StatelessWidget {
  final CivilDate date;
  final Duration utcOffset;
  final Strings strings;

  const DayDetail({
    super.key,
    required this.date,
    required this.utcOffset,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final moon = Moon.of(date, utcOffset: utcOffset);

    final primary = theme.type.body.copyWith(color: colors.textPrimary);
    final faint = theme.type.label.copyWith(color: colors.textSecondary);

    Widget rule() => Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.md),
      child: Container(height: 1, color: colors.outline.withValues(alpha: 0.6)),
    );

    // A system's row: its name at the left, its value at the right, the
    // value in two tiers.
    Widget row(
      String key,
      String label,
      Widget value, [
      List<ReadingPart>? under,
    ]) => Padding(
      key: ValueKey('detail-$key'),
      padding: EdgeInsets.symmetric(vertical: spacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              label.toUpperCase(),
              style: theme.type.caption.copyWith(
                color: colors.textFaint,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                value,
                if (under != null && under.isNotEmpty) ...[
                  SizedBox(height: spacing.xs / 2),
                  _parts(under, faint, TextAlign.end),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    Widget plain(String text) =>
        Text(text, textAlign: TextAlign.end, style: primary);
    ReadingPart part(String text) => (text: text, color: null);

    final weton = Weton.of(date);
    final javanese = JavaneseDate.supports(date) ? JavaneseDate.of(date) : null;
    final mangsa = PranataMangsa.supports(date) ? PranataMangsa.of(date) : null;
    final hijri = HijriDate.supports(date) ? HijriDate.of(date) : null;
    final chinese = ChineseDate.supports(date) ? ChineseDate.of(date) : null;
    final bazi = Bazi.of(date, utcOffset: utcOffset);

    // The head: the moon, and the day and the moon said.
    const moonSize = 72.0;
    final head = Row(
      key: const ValueKey('detail-head'),
      children: [
        TracedMoon(
          key: ValueKey('detail-moon-$date'),
          moon: moon,
          size: moonSize,
          color: colors.textPrimary,
        ),
        SizedBox(width: spacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.gregorian(date),
                key: const ValueKey('detail-date'),
                style: theme.type.title.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: spacing.xs),
              Text(
                strings.moonPhase(moon.phase),
                key: const ValueKey('detail-moon-phase'),
                style: primary.copyWith(color: colors.accent),
              ),
              Text(
                '${(moon.illumination * 100).round()}% '
                '${strings.moonLit.toLowerCase()}',
                key: const ValueKey('detail-moon-lit'),
                style: faint,
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, spacing.md, spacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          rule(),
          // The Javanese reckonings.
          row(
            'weton',
            strings.systemLabel(CalendarSystem.weton),
            plain('$weton'),
            [part('neptu ${weton.neptu}')],
          ),
          if (javanese != null)
            row(
              'javanese',
              strings.systemLabel(CalendarSystem.javanese),
              plain('${javanese.day} ${javanese.month.label}'),
              [part('${javanese.year} ${javanese.taun.label}')],
            ),
          if (mangsa != null)
            row(
              'mangsa',
              strings.mangsa,
              plain('${mangsa.day} ${mangsa.mangsa.label}'),
              [part('${mangsa.year} · ${mangsa.mangsa.season.label}')],
            ),
          if (hijri != null) ...[
            rule(),
            row(
              'hijri',
              strings.systemLabel(CalendarSystem.hijri),
              plain('${hijri.day} ${strings.hijriMonth(hijri.month)}'),
              [part(_after(strings.hijri(hijri), hijri.month, strings))],
            ),
          ],
          // Last, the two in characters.
          rule(),
          if (chinese != null)
            row(
              'chinese',
              strings.systemLabel(CalendarSystem.chinese),
              _parts(
                [
                  dayElementPart(date),
                  part(' '),
                  part(
                    strings.chineseDateInHanzi
                        ? Strings.chineseHanzi(chinese)
                        : strings.chinese(chinese),
                  ),
                ],
                primary,
                TextAlign.end,
              ),
              shortZodiacParts(chinese, strings, hanzi: false),
            ),
          row(
            'bazi',
            strings.bazi,
            _Pillars(bazi: bazi, style: primary, caption: faint),
            _turn(bazi, utcOffset),
          ),
        ],
      ),
    );
  }

  // The Hijri year and era: what follows the month in the full date.
  static String _after(String full, HijriMonth month, Strings strings) {
    final name = strings.hijriMonth(month);
    final at = full.indexOf(name);
    return at < 0 ? full : full.substring(at + name.length).trim();
  }

  // The solar term that turns the month on this day, and its minute.
  static List<ReadingPart>? _turn(Bazi bazi, Duration utcOffset) {
    final parts = baziParts(bazi, utcOffset);
    final at = parts.indexWhere((p) => p.text.startsWith(' · '));
    if (at < 0) return null;
    return [(text: parts[at].text.substring(3), color: null)];
  }

  static Widget _parts(
    List<ReadingPart> parts,
    TextStyle style,
    TextAlign align,
  ) => Text.rich(
    TextSpan(
      children: [
        for (final part in parts)
          TextSpan(
            text: part.text,
            style: part.color == null ? null : TextStyle(color: part.color),
          ),
      ],
    ),
    textAlign: align,
    style: style,
  );
}

/// The bazi's year, month and day pillars side by side, each a stem in
/// its element's colour over its branch's character, and under it what it
/// is the pillar of.
class _Pillars extends StatelessWidget {
  final Bazi bazi;
  final TextStyle style;
  final TextStyle caption;

  const _Pillars({
    required this.bazi,
    required this.style,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = SmTheme.of(context).spacing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (pillar, mark)) in [
          (bazi.year, '年'),
          (bazi.month, '月'),
          (bazi.day, '日'),
        ].indexed) ...[
          if (i > 0) SizedBox(width: spacing.md),
          Column(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: pillar.stem.hanzi,
                      style: TextStyle(color: elementColors[pillar.stem.unsur]),
                    ),
                    TextSpan(text: pillar.branch.hanzi),
                  ],
                ),
                style: style,
              ),
              Text(mark, style: caption),
            ],
          ),
        ],
      ],
    );
  }
}
