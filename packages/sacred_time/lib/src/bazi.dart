import 'chinese_date.dart';
import 'civil_date.dart';
import 'sun.dart';

/// The ten heavenly stems. They go in pairs through the five elements, the
/// first of each pair yang and the second yin.
enum Stem {
  jia('甲', 'Jia'),
  yi('乙', 'Yi'),
  bing('丙', 'Bing'),
  ding('丁', 'Ding'),
  wu('戊', 'Wu'),
  ji('己', 'Ji'),
  geng('庚', 'Geng'),
  xin('辛', 'Xin'),
  ren('壬', 'Ren'),
  gui('癸', 'Gui');

  final String hanzi;
  final String label;

  const Stem(this.hanzi, this.label);

  Unsur get unsur => Unsur.values[index ~/ 2];
  bool get isYang => index.isEven;
}

/// The twelve earthly branches, each with its animal.
enum Branch {
  zi('子', 'Zi'),
  chou('丑', 'Chou'),
  yin('寅', 'Yin'),
  mao('卯', 'Mao'),
  chen('辰', 'Chen'),
  si('巳', 'Si'),
  wu('午', 'Wu'),
  wei('未', 'Wei'),
  shen('申', 'Shen'),
  you('酉', 'You'),
  xu('戌', 'Xu'),
  hai('亥', 'Hai');

  final String hanzi;
  final String label;

  const Branch(this.hanzi, this.label);

  Shio get shio => Shio.values[index];
}

/// A stem over a branch: one of the sixty pairs of the cycle.
class Pillar {
  final Stem stem;
  final Branch branch;

  const Pillar(this.stem, this.branch);

  /// The pair at [index] in the cycle of sixty, jiazi being 0.
  factory Pillar.ofCycle(int index) =>
      Pillar(Stem.values[index % 10], Branch.values[index % 12]);

  String get hanzi => '${stem.hanzi}${branch.hanzi}';

  /// Where the pair stands in the cycle of sixty, jiazi being 0. A stem
  /// and a branch move through it together: stepping a pillar is stepping
  /// this, never the two apart.
  int get cycleIndex => (6 * stem.index - 5 * branch.index) % 60;

  /// The pillar [steps] further on in the cycle, or back if negative.
  Pillar step(int steps) => Pillar.ofCycle((cycleIndex + steps) % 60);

  @override
  bool operator ==(Object other) =>
      other is Pillar && other.stem == stem && other.branch == branch;

  @override
  int get hashCode => Object.hash(stem, branch);

  @override
  String toString() => '${stem.label} ${branch.label}';
}

/// The pillars of a day in the sexagenary reckoning (bazi): year, month
/// and day, each a stem and a branch. The fourth pillar is the hour's,
/// which a date alone does not have.
///
/// Unlike the Chinese calendar's own months and years, these follow the
/// sun: the year turns at Lichun, the start of spring around 4 February,
/// not at the new year, and each month starts at one of the twelve solar
/// terms that fall every thirty degrees of the sun's path from there.
///
/// Two choices are made where a date leaves it open. A term falls at an
/// instant; the whole civil day it falls in is counted as already in the
/// new month, and [turnsAt] says when in the day it does turn. And the
/// day changes at midnight, as everywhere else here, not at eleven at
/// night as strict practice has it. A chart of an instant, which leaves
/// nothing open, is a [BaziChart].
class Bazi {
  final Pillar year;
  final Pillar month;
  final Pillar day;

  /// The instant, in Universal Time, the month pillar turns within this
  /// day, and the year's with it at Lichun; null on every other day.
  final DateTime? turnsAt;

  const Bazi._(this.year, this.month, this.day, this.turnsAt);

  factory Bazi.of(CivilDate date, {required Duration utcOffset}) {
    final midnight = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(utcOffset);
    // The sun at the end of the civil day.
    final endOfDay = midnight.add(const Duration(days: 1));
    int monthAt(DateTime instant) =>
        ((Sun.apparentLongitudeAt(Sun.julianDayOf(instant)) - 315) % 360) ~/ 30;
    // Which of the twelve solar months it is in, the tiger month being 0.
    final solarMonth = monthAt(endOfDay);
    final turnsAt = monthAt(midnight) == solarMonth
        ? null
        : Sun.nextCrossing(midnight, (315 + 30.0 * solarMonth) % 360);
    // January, and February before Lichun, still belong to the old year.
    final solarYear = date.month <= 2 && solarMonth >= 10
        ? date.year - 1
        : date.year;

    final year = Pillar.ofCycle((solarYear - 4) % 60);
    return Bazi._(
      year,
      Pillar(
        // The tiger month's stem is fixed by the year's: the rule of the
        // five tigers. The rest follow in order.
        Stem.values[(year.stem.index % 5 * 2 + 2 + solarMonth) % 10],
        Branch.values[(solarMonth + 2) % 12],
      ),
      // The days have counted round the sixty without a break; 1 October
      // 1949 was a jiazi day.
      Pillar.ofCycle((date.dayNumber + 49) % 60),
      turnsAt,
    );
  }

  @override
  String toString() => '$year · $month · $day';
}
