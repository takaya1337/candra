import 'bazi.dart';
import 'chinese_date.dart';
import 'civil_date.dart';
import 'sun.dart';

/// Which time a chart's day and hour are read from.
enum TimeMode {
  /// The clock, as it stood.
  clock,

  /// The clock put right for how far the place is from its zone's own
  /// meridian: four minutes a degree.
  trueSolarLongitudeOnly,

  /// That, and the equation of time as well: the time a sundial there
  /// would have shown.
  trueSolar,
}

/// Which day the hour before midnight belongs to. Schools differ, and
/// nothing in the astronomy settles it.
enum ZiHourRule {
  /// The day that is ending keeps it (late zi, 晚子時 or 夜子時): the day
  /// pillar does not go on, but the hour pillar does, taking its stem
  /// from the coming day. So 袁樹珊 in 《命理探原》: born on a 辛酉 day
  /// in the night zi hour, read 辛酉 day, 庚子 hour, "the hour worked
  /// from the 壬 day".
  split,

  /// The day that is coming takes it: the day turns at eleven at night.
  /// So 韋千里 in 《千里命稿》, who will have no early and late zi.
  unified,

  /// The day turns at midnight by the sun, whatever the clock says. The
  /// hour is then read by the sun as well, whatever the [TimeMode], so
  /// that the day and the hour are never taken from two different
  /// clocks; and in the hour before that midnight the hour pillar goes
  /// on to the coming day's, as under [split].
  trueSolarMidnight,
}

/// Where the year turns.
enum YearBoundary {
  /// At Lichun, the sun at 315 degrees: the rule of the art.
  lichun,

  /// At the lunar new year. Kept only to match charts made elsewhere.
  lunarNewYear,
}

/// Where the count to a luck pillar's start is taken to.
enum LuckAnchor {
  /// The instant of the solar term.
  termInstant,

  /// The start of the civil day the term falls in.
  termDay,
}

/// How the age a luck pillar starts at is given.
enum LuckRounding {
  /// In full: years, months and days.
  exact,

  /// In whole years, the rest cut off.
  floorYears,

  /// To the nearest whole year.
  nearestYear,
}

/// Every choice a chart rests on that the astronomy does not make. A
/// chart keeps its own, so it can always be worked out again.
class BaziConfig {
  final TimeMode timeMode;
  final ZiHourRule ziHourRule;
  final YearBoundary yearBoundary;

  /// Days from birth to the term that count as one year of age.
  final double luckDivisor;
  final LuckAnchor luckAnchor;
  final LuckRounding luckRounding;

  const BaziConfig({
    this.timeMode = TimeMode.trueSolar,
    this.ziHourRule = ZiHourRule.split,
    this.yearBoundary = YearBoundary.lichun,
    this.luckDivisor = 3,
    this.luckAnchor = LuckAnchor.termInstant,
    this.luckRounding = LuckRounding.exact,
  });

  BaziConfig copyWith({
    TimeMode? timeMode,
    ZiHourRule? ziHourRule,
    YearBoundary? yearBoundary,
    double? luckDivisor,
    LuckAnchor? luckAnchor,
    LuckRounding? luckRounding,
  }) => BaziConfig(
    timeMode: timeMode ?? this.timeMode,
    ziHourRule: ziHourRule ?? this.ziHourRule,
    yearBoundary: yearBoundary ?? this.yearBoundary,
    luckDivisor: luckDivisor ?? this.luckDivisor,
    luckAnchor: luckAnchor ?? this.luckAnchor,
    luckRounding: luckRounding ?? this.luckRounding,
  );
}

/// The four pillars of an instant at a place: year, month, day and hour.
///
/// The year and month pillars turn at instants, the sun's crossings of
/// the twelve node terms, worked out to the minute and never looked up;
/// they are the same wherever the instant is read from. The day and hour
/// pillars are read from the time at the place, as the [BaziConfig] says.
class BaziChart {
  /// The instant, in Universal Time.
  final DateTime instant;

  /// The offset of the clock at the place then.
  final Duration utcOffset;

  /// Degrees east of Greenwich, if known. Without it the chart is read
  /// from the clock, whatever the [TimeMode].
  final double? longitude;
  final BaziConfig config;

  final Pillar year;
  final Pillar month;
  final Pillar day;
  final Pillar hour;

  /// What was added to the clock to get the time the day and hour were
  /// read from.
  final Duration correction;

  const BaziChart._({
    required this.instant,
    required this.utcOffset,
    required this.longitude,
    required this.config,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.correction,
  });

  factory BaziChart.at(
    DateTime instant, {
    required Duration utcOffset,
    double? longitude,
    BaziConfig config = const BaziConfig(),
  }) {
    final utc = instant.toUtc();
    final julianDay = Sun.julianDayOf(utc);
    final clock = utc.add(utcOffset);

    // The year and the month, from where the sun is.
    final solarMonth = ((Sun.apparentLongitudeAt(julianDay) - 315) % 360) ~/ 30;
    // January, and February before Lichun, still belong to the old year.
    var solarYear = clock.month <= 2 && solarMonth >= 10
        ? clock.year - 1
        : clock.year;
    if (config.yearBoundary == YearBoundary.lunarNewYear) {
      final date = CivilDate(clock.year, clock.month, clock.day);
      if (ChineseDate.supports(date)) {
        solarYear = ChineseDate.of(date).kongziliYear - 551;
      }
    }
    final year = Pillar.ofCycle((solarYear - 4) % 60);
    final month = Pillar(
      // The rule of the five tigers: the year's stem fixes the tiger
      // month's, and the rest follow in order.
      Stem.values[(year.stem.index % 5 * 2 + 2 + solarMonth) % 10],
      Branch.values[(solarMonth + 2) % 12],
    );

    // The day and the hour, from the time at the place.
    final offMeridian = longitude == null
        ? Duration.zero
        : _minutes((longitude - utcOffset.inSeconds / 240) * 4);
    final sundial = longitude == null
        ? Duration.zero
        : offMeridian + _minutes(Sun.equationOfTimeAt(julianDay));
    // When the day turns by the sun, the hour is read by the sun too:
    // a sundial day with a clock hour can put the zi hour on the wrong
    // side of midnight, a whole day out.
    final correction = config.ziHourRule == ZiHourRule.trueSolarMidnight
        ? sundial
        : switch (config.timeMode) {
            TimeMode.clock => Duration.zero,
            TimeMode.trueSolarLongitudeOnly => offMeridian,
            TimeMode.trueSolar => sundial,
          };
    final chartTime = clock.add(correction);
    final hourPlace = (chartTime.hour + 1) ~/ 2 % 12;

    var date = CivilDate(chartTime.year, chartTime.month, chartTime.day);
    if (config.ziHourRule == ZiHourRule.unified && chartTime.hour == 23) {
      date = date.addDays(1);
    }
    // The days have counted round the sixty without a break.
    final day = Pillar.ofCycle((date.dayNumber + 49) % 60);
    // In the hour before midnight the hour pillar has already gone on to
    // the coming day's, whichever day the day pillar is given to: under
    // the split rule "the day pillar does not go on, only the hour
    // pillar does".
    final hourOf =
        chartTime.hour == 23 && config.ziHourRule != ZiHourRule.unified
        ? day.step(1)
        : day;
    final hour = Pillar(
      // The rule of the five rats: the day's stem fixes the zi hour's.
      Stem.values[(hourOf.stem.index % 5 * 2 + hourPlace) % 10],
      Branch.values[hourPlace],
    );

    return BaziChart._(
      instant: utc,
      utcOffset: utcOffset,
      longitude: longitude,
      config: config,
      year: year,
      month: month,
      day: day,
      hour: hour,
      correction: correction,
    );
  }

  static Duration _minutes(double minutes) =>
      Duration(seconds: (minutes * 60).round());

  /// The same instant and place, read by other choices.
  BaziChart withConfig(BaziConfig config) => BaziChart.at(
    instant,
    utcOffset: utcOffset,
    longitude: longitude,
    config: config,
  );

  /// The clock at the place, as wall-clock fields.
  DateTime get clockTime => instant.add(utcOffset);

  /// The time the day and hour were read from.
  DateTime get chartTime => clockTime.add(correction);

  /// The self: the day's stem, which the rest of the chart is read
  /// against.
  Stem get dayMaster => day.stem;

  /// Whether the chart falls in the hour before midnight, where the day
  /// pillar depends on the [ZiHourRule]: another school would read a
  /// different day, and so a different self.
  bool get inLateZiHour => chartTime.hour == 23;

  // The sun's longitude at the node term that opened the month.
  double get _nodeBehind => (315 + 30 * ((month.branch.index - 2) % 12)) % 360;

  /// The node term that opened this month, in Universal Time.
  DateTime get termBefore => Sun.previousCrossing(instant, _nodeBehind);

  /// The node term that will close it.
  DateTime get termAfter => Sun.nextCrossing(
    instant.add(const Duration(seconds: 2)),
    (_nodeBehind + 30) % 360,
  );

  /// The luck pillars, which need to know whether the person is male.
  LuckPillars luck({required bool male, int count = 8}) {
    // Yang year and male, or yin year and female, go forward.
    final forward = year.stem.isYang == male;
    var term = forward ? termAfter : termBefore;
    if (config.luckAnchor == LuckAnchor.termDay) {
      final local = term.add(utcOffset);
      term = DateTime.utc(
        local.year,
        local.month,
        local.day,
      ).subtract(utcOffset);
    }
    final days =
        (forward ? term.difference(instant) : instant.difference(term))
            .inSeconds
            .abs() /
        Duration.secondsPerDay;
    return LuckPillars._(
      forward: forward,
      startAge: days / config.luckDivisor,
      rounding: config.luckRounding,
      pillars: [for (var i = 1; i <= count; i++) month.step(forward ? i : -i)],
    );
  }

  @override
  String toString() => '$year · $month · $day · $hour';
}

/// The ten-year periods of a life, stepping through the cycle of sixty
/// from the month pillar.
class LuckPillars {
  /// Whether they step forward through the cycle, or back.
  final bool forward;

  /// The age at which the first begins, in years, unrounded. Each later
  /// one begins ten years after the one before.
  final double startAge;
  final LuckRounding rounding;
  final List<Pillar> pillars;

  const LuckPillars._({
    required this.forward,
    required this.startAge,
    required this.rounding,
    required this.pillars,
  });

  /// The age the first begins at in whole years, as the [rounding] has
  /// it: to the nearest, or else cut short.
  int get firstAge => rounding == LuckRounding.nearestYear
      ? startAge.round()
      : startAge.floor();

  /// [startAge] as years, months and days, each cut short, with a month
  /// reckoned at thirty days.
  ({int years, int months, int days}) get startAgeParts {
    final years = startAge.floor();
    final months = ((startAge - years) * 12).floor();
    final days = (((startAge - years) * 12 - months) * 30).floor();
    return (years: years, months: months, days: days);
  }
}

/// What another stem is to the self, the day's stem: one of ten, by how
/// their elements stand to each other and whether both are yang or both
/// yin. The names are the same in every school; what is made of them is
/// not, and is no business of a calendar.
enum TenGod {
  peer('比肩', 'Bijian'),
  rival('劫財', 'Jiecai'),
  eatingGod('食神', 'Shishen'),
  hurtingOfficer('傷官', 'Shangguan'),
  indirectWealth('偏財', 'Piancai'),
  directWealth('正財', 'Zhengcai'),
  sevenKillings('七殺', 'Qisha'),
  directOfficer('正官', 'Zhengguan'),
  indirectSeal('偏印', 'Pianyin'),
  directSeal('正印', 'Zhengyin');

  final String hanzi;
  final String label;

  const TenGod(this.hanzi, this.label);

  /// What [other] is to [self].
  static TenGod of(Stem self, Stem other) {
    // How many steps round the cycle of generation the other's element
    // is from the self's: 0 the same, 1 what it feeds, 2 what it masters,
    // 3 what masters it, 4 what feeds it.
    final steps = (other.unsur.index - self.unsur.index) % 5;
    final alike = self.isYang == other.isYang;
    return switch (steps) {
      0 => alike ? peer : rival,
      1 => alike ? eatingGod : hurtingOfficer,
      2 => alike ? indirectWealth : directWealth,
      3 => alike ? sevenKillings : directOfficer,
      _ => alike ? indirectSeal : directSeal,
    };
  }
}

/// The relations between branches that every school agrees on, and that
/// are plain arithmetic. The punishments and the harms are not among
/// them: schools differ on those, so they are kept as named tables, not
/// worked out here.
extension BranchRelations on Branch {
  /// The branch opposite: the six clashes (六冲).
  Branch get clash => Branch.values[(index + 6) % 12];

  /// The branch it pairs with: the six harmonies (六合).
  Branch get harmony => Branch.values[(13 - index) % 12];

  /// The element of the three-branch harmony (三合) it belongs to.
  Unsur get trine =>
      const [Unsur.air, Unsur.logam, Unsur.api, Unsur.kayu][index % 4];
}

/// What a pillar carries besides its stem and branch, the same in every
/// school and plain arithmetic on its place in the cycle of sixty.
extension PillarLore on Pillar {
  // The thirty names, each shared by two pillars running. Some tables
  // write 井泉水 for 泉中水.
  static const _nayin = [
    '海中金',
    '爐中火',
    '大林木',
    '路旁土',
    '劍鋒金',
    '山頭火',
    '澗下水',
    '城頭土',
    '白蠟金',
    '楊柳木',
    '泉中水',
    '屋上土',
    '霹靂火',
    '松柏木',
    '長流水',
    '沙中金',
    '山下火',
    '平地木',
    '壁上土',
    '金箔金',
    '覆燈火',
    '天河水',
    '大驛土',
    '釵釧金',
    '桑柘木',
    '大溪水',
    '沙中土',
    '天上火',
    '石榴木',
    '大海水',
  ];

  /// Its nayin (納音), the "sounded" element of the pair: three
  /// characters, the last of them the element.
  String get nayin => _nayin[cycleIndex ~/ 2];

  /// The element its [nayin] names.
  Unsur get nayinElement => Unsur.values['木火土金水'.indexOf(nayin.substring(2))];

  /// The two branches its ten-day week (旬) does not reach: the void
  /// (空亡).
  List<Branch> get voidBranches {
    final first = (10 - 2 * (cycleIndex ~/ 10)) % 12;
    return [Branch.values[first], Branch.values[first + 1]];
  }
}

/// The five combinations of stems (天干五合), the same in every school.
extension StemRelations on Stem {
  /// The stem it combines with: the one five on.
  Stem get combination => Stem.values[(index + 5) % 10];

  /// The element the two are said to turn into.
  Unsur get combinedElement => Unsur.values[(index % 5 + 2) % 5];
}
