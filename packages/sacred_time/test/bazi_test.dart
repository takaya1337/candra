import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  const beijing = Duration(hours: 8);

  String pillars(int year, int month, int day, {Duration offset = beijing}) {
    final bazi = Bazi.of(CivilDate(year, month, day), utcOffset: offset);
    return '${bazi.year.hanzi} ${bazi.month.hanzi} ${bazi.day.hanzi}';
  }

  test('known days', () {
    // The first day of 2000: still the rabbit year, in the rat month.
    expect(pillars(2000, 1, 1), '己卯 丙子 戊午');
    // The founding day of the People's Republic was a jiazi day.
    expect(pillars(1949, 10, 1), '己丑 癸酉 甲子');
    // 11 October 2026.
    // Exactly 163 rounds of sixty after 1 January 2000: the same day pillar.
    expect(pillars(2026, 10, 11), '丙午 戊戌 戊午');
  });

  test('on a term\'s day says the minute the month turns, and on no '
      'other day', () {
    // Lichun 2026: 3 February, 20:02 Universal Time; the 4th in Beijing.
    final lichun = Bazi.of(CivilDate(2026, 2, 4), utcOffset: beijing);
    expect(lichun.year.hanzi, '丙午');
    expect(
      lichun.turnsAt!.difference(DateTime.utc(2026, 2, 3, 20, 2)).abs(),
      lessThan(const Duration(minutes: 1)),
    );
    expect(Bazi.of(CivilDate(2026, 2, 3), utcOffset: beijing).turnsAt, isNull);
    expect(Bazi.of(CivilDate(2026, 2, 5), utcOffset: beijing).turnsAt, isNull);
    // Read from Honolulu the same instant falls on the 3rd.
    const honolulu = Duration(hours: -10);
    expect(
      Bazi.of(CivilDate(2026, 2, 3), utcOffset: honolulu).turnsAt,
      lichun.turnsAt,
    );
    // Twelve days a year have one.
    var days = 0;
    for (var d = CivilDate(2026, 1, 1); d.year == 2026; d = d.addDays(1)) {
      if (Bazi.of(d, utcOffset: beijing).turnsAt != null) days++;
    }
    expect(days, 12);
  });

  test('the year turns at Lichun, not at the new year', () {
    // Lichun 2024 fell on 4 February; the Chinese new year not until the
    // 10th.
    expect(pillars(2024, 2, 3), '癸卯 乙丑 丁酉');
    expect(pillars(2024, 2, 4), '甲辰 丙寅 戊戌');
    expect(pillars(2024, 2, 9), startsWith('甲辰 丙寅'));
    // And 1 January is never yet the new year.
    for (var year = 1990; year < 2040; year++) {
      final january = Bazi.of(CivilDate(year, 1, 1), utcOffset: beijing);
      final march = Bazi.of(CivilDate(year, 3, 1), utcOffset: beijing);
      expect(january.year, Pillar.ofCycle((year - 5) % 60));
      expect(march.year, Pillar.ofCycle((year - 4) % 60));
    }
  });

  test('the months turn at the solar terms, twelve to a year', () {
    // Jingzhe 2026 falls on 5 March, Qingming on 5 April.
    expect(pillars(2026, 3, 4), startsWith('丙午 庚寅'));
    expect(pillars(2026, 3, 5), startsWith('丙午 辛卯'));
    expect(pillars(2026, 4, 4), startsWith('丙午 辛卯'));
    expect(pillars(2026, 4, 5), startsWith('丙午 壬辰'));

    // Through a whole year: every branch once, in order, about a month
    // each, the stems stepping with them.
    final seen = <Pillar>[];
    for (var day = 0; day < 365; day++) {
      final month = Bazi.of(
        CivilDate(2026, 2, 4).addDays(day),
        utcOffset: beijing,
      ).month;
      if (seen.isEmpty || seen.last != month) seen.add(month);
    }
    expect(seen, hasLength(12));
    expect(seen.first.branch, Branch.yin);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i].branch.index, (seen[i - 1].branch.index + 1) % 12);
      expect(seen[i].stem.index, (seen[i - 1].stem.index + 1) % 10);
    }
  });

  test('the days count round the sixty without a break', () {
    final start = CivilDate(2026, 1, 1);
    final first = Bazi.of(start, utcOffset: beijing).day;
    for (var i = 1; i <= 120; i++) {
      final day = Bazi.of(start.addDays(i), utcOffset: beijing).day;
      expect(day.stem.index, (first.stem.index + i) % 10);
      expect(day.branch.index, (first.branch.index + i) % 12);
    }
    expect(Bazi.of(start.addDays(60), utcOffset: beijing).day, first);
  });

  test('stems and branches carry their elements and animals', () {
    expect(Stem.jia.unsur, Unsur.kayu);
    expect(Stem.gui.unsur, Unsur.air);
    expect(Stem.bing.isYang, isTrue);
    expect(Stem.ding.isYang, isFalse);
    expect(Branch.wu.shio, Shio.kuda);
    expect(Branch.zi.shio, Shio.tikus);
    // The day's element is its stem's.
    for (var i = 0; i < 20; i++) {
      final date = CivilDate(2026, 10, 1).addDays(i);
      expect(
        Bazi.of(date, utcOffset: beijing).day.stem.unsur,
        ChineseDate.dayUnsur(date),
      );
    }
    expect(
      '${Bazi.of(CivilDate(2000, 1, 1), utcOffset: beijing)}',
      'Ji Mao · Bing Zi · Wu Wu',
    );
  });
}
