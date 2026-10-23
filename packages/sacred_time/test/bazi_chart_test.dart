import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  const wib = Duration(hours: 7);
  const beijing = Duration(hours: 8);
  const clock = BaziConfig(timeMode: TimeMode.clock);

  // A chart for a clock time at an offset, read from the clock.
  BaziChart at(
    int year,
    int month,
    int day,
    int hour,
    int minute, {
    Duration offset = wib,
    double? longitude,
    BaziConfig config = clock,
  }) => BaziChart.at(
    DateTime.utc(year, month, day, hour, minute).subtract(offset),
    utcOffset: offset,
    longitude: longitude,
    config: config,
  );

  group('the cycle of sixty', () {
    test('has sixty pairs, never a yang stem on a yin branch', () {
      final seen = <String>{};
      for (var i = 0; i < 60; i++) {
        final pillar = Pillar.ofCycle(i);
        expect(pillar.stem.index.isEven, pillar.branch.index.isEven);
        expect(pillar.cycleIndex, i);
        seen.add(pillar.hanzi);
      }
      expect(seen, hasLength(60));
      expect(seen, isNot(contains('甲丑')));
      expect(Pillar.ofCycle(0).hanzi, '甲子');
      expect(Pillar.ofCycle(59).step(1).hanzi, '甲子');
      expect(Pillar.ofCycle(0).step(-1).hanzi, '癸亥');
    });
  });

  group('the day pillar', () {
    test('agrees with every anchor: it is one unbroken count', () {
      expect(at(2000, 1, 1, 12, 0).day.hanzi, '戊午');
      expect(at(1900, 1, 1, 12, 0).day.hanzi, '甲戌');
      expect(at(1949, 10, 1, 12, 0).day.hanzi, '甲子');
      expect(at(2026, 10, 12, 12, 0).day.hanzi, '己未');
    });
  });

  group('the year pillar', () {
    test('turns at Lichun, to the minute, not at the lunar new year', () {
      // Lichun 2026: 3 February, 20:02 Universal Time.
      final before = BaziChart.at(
        DateTime.utc(2026, 2, 3, 20, 1),
        utcOffset: beijing,
      );
      final after = BaziChart.at(
        DateTime.utc(2026, 2, 3, 20, 3),
        utcOffset: beijing,
      );
      expect(before.year.hanzi, '乙巳');
      expect(before.month.hanzi, '己丑');
      expect(after.year.hanzi, '丙午');
      expect(after.month.hanzi, '庚寅');
      // The same instant is the same year wherever it is read from.
      expect(
        BaziChart.at(DateTime.utc(2026, 2, 3, 20, 3), utcOffset: wib).year,
        after.year,
      );
    });

    test('28 January 1990 is still the year before, though the lunar new '
        'year had come the day before', () {
      final chart = at(1990, 1, 28, 12, 0, offset: beijing);
      expect(chart.year.hanzi, '己巳');
      // Only by the other rule, kept to match other apps, is it the new
      // year already.
      final lunar = chart.withConfig(
        clock.copyWith(yearBoundary: YearBoundary.lunarNewYear),
      );
      expect(lunar.year.hanzi, '庚午');
      // By both it is the new year after Lichun.
      expect(at(1990, 2, 5, 12, 0, offset: beijing).year.hanzi, '庚午');
    });

    test('1984 began a cycle', () {
      expect(at(1984, 6, 1, 12, 0).year.hanzi, '甲子');
      expect(at(2044, 6, 1, 12, 0).year.hanzi, '甲子');
    });
  });

  group('the month pillar', () {
    test('turns at each of the twelve nodes and at none of the breaths', () {
      // Hanlu 2026: 8 October, 06:29 Universal Time.
      expect(
        BaziChart.at(
          DateTime.utc(2026, 10, 8, 6, 28),
          utcOffset: wib,
        ).month.hanzi,
        '丁酉',
      );
      expect(
        BaziChart.at(
          DateTime.utc(2026, 10, 8, 6, 30),
          utcOffset: wib,
        ).month.hanzi,
        '戊戌',
      );
      // Shuangjiang, the breath in the middle of it, changes nothing.
      expect(at(2026, 10, 22, 12, 0).month.hanzi, '戊戌');
      expect(at(2026, 10, 25, 12, 0).month.hanzi, '戊戌');
    });

    test('goes through all twelve branches in a year, the stems by the '
        'rule of the five tigers', () {
      // A bing year: the tiger month is gengyin.
      final months = [
        for (final (month, day) in [
          (2, 10),
          (3, 10),
          (4, 10),
          (5, 10),
          (6, 10),
          (7, 10),
          (8, 10),
          (9, 10),
          (10, 10),
          (11, 10),
          (12, 10),
        ])
          at(2026, month, day, 12, 0).month.hanzi,
        // The ox month runs into the next January, still of this year.
        at(2027, 1, 10, 12, 0).month.hanzi,
      ];
      expect(months, [
        '庚寅',
        '辛卯',
        '壬辰',
        '癸巳',
        '甲午',
        '乙未',
        '丙申',
        '丁酉',
        '戊戌',
        '己亥',
        '庚子',
        '辛丑',
      ]);
      expect(at(2027, 1, 10, 12, 0).year.hanzi, '丙午');
    });

    test('knows the terms either side of it', () {
      final chart = at(2026, 10, 12, 12, 0);
      expect(
        chart.termBefore,
        DateTime.utc(
          2026,
          10,
          8,
          6,
          29,
          1,
        ).copyWith(second: chart.termBefore.second),
      );
      expect(chart.termBefore.minute, anyOf(28, 29));
      expect(chart.termAfter.month, 11);
      expect(chart.termAfter.day, 7);
    });
  });

  group('the hour pillar', () {
    test('goes through the twelve double hours, the stems by the rule of '
        'the five rats', () {
      // 12 October 2026 is a jiwei day: its zi hour is jiazi.
      expect(at(2026, 10, 12, 0, 30).hour.hanzi, '甲子');
      expect(at(2026, 10, 12, 1, 0).hour.hanzi, '乙丑');
      expect(at(2026, 10, 12, 10, 0).hour.hanzi, '己巳');
      expect(at(2026, 10, 12, 12, 59).hour.hanzi, '庚午');
      expect(at(2026, 10, 12, 22, 59).hour.hanzi, '乙亥');
    });

    test('before midnight belongs to whichever day the school says', () {
      final late = at(2026, 10, 12, 23, 30);
      expect(late.inLateZiHour, isTrue);
      // Split: the day that is ending keeps it, but the hour pillar has
      // gone on to the coming day's zi hour.
      expect(late.day.hanzi, '己未');
      expect(late.hour.hanzi, '丙子');
      // Unified: the coming day takes it, and with it the self changes.
      final unified = late.withConfig(
        clock.copyWith(ziHourRule: ZiHourRule.unified),
      );
      expect(unified.day.hanzi, '庚申');
      expect(unified.hour.hanzi, '丙子');
      expect(unified.dayMaster, isNot(late.dayMaster));
      // Year and month are untouched by it.
      expect(unified.month, late.month);
      // After midnight every school agrees.
      for (final rule in ZiHourRule.values) {
        final early = at(
          2026,
          10,
          13,
          0,
          30,
          config: clock.copyWith(ziHourRule: rule),
        );
        expect(early.day.hanzi, '庚申');
        expect(early.hour.hanzi, '丙子');
        expect(early.inLateZiHour, isFalse);
      }
    });
  });

  group('true solar time', () {
    test('is the clock put right for the meridian and the sundial', () {
      // Medan is well west of the meridian its clock keeps.
      final medan = at(
        2026,
        6,
        13,
        12,
        0,
        longitude: 98.67,
        config: const BaziConfig(timeMode: TimeMode.trueSolarLongitudeOnly),
      );
      expect(medan.correction.inSeconds / 60, closeTo(-25.3, 0.1));
      // In mid-June the sundial and the mean sun agree.
      final full = medan.withConfig(const BaziConfig());
      expect(full.correction.inSeconds / 60, closeTo(-25.3, 0.6));
      // In early November it is some sixteen minutes ahead.
      final november = at(
        2026,
        11,
        3,
        12,
        0,
        longitude: 98.67,
        config: const BaziConfig(),
      );
      expect(november.correction.inSeconds / 60, closeTo(-25.3 + 16.4, 0.4));
      // Urumqi keeps Beijing's clock, more than two hours off its sun.
      final urumqi = at(
        2026,
        6,
        13,
        12,
        0,
        offset: beijing,
        longitude: 87.6,
        config: const BaziConfig(timeMode: TimeMode.trueSolarLongitudeOnly),
      );
      expect(urumqi.correction.inMinutes, closeTo(-130, 1));
      expect(urumqi.hour.branch, Branch.si);
      expect(urumqi.withConfig(clock).hour.branch, Branch.wu);
    });

    test('can move a birth across an hour, and across the day', () {
      // 23:10 by the clock in Medan is 22:45 by its meridian: not yet
      // the zi hour, and no question of which day.
      final byClock = at(2026, 6, 13, 23, 10, longitude: 98.67);
      final bySun = byClock.withConfig(
        const BaziConfig(timeMode: TimeMode.trueSolarLongitudeOnly),
      );
      expect(byClock.hour.branch, Branch.zi);
      expect(byClock.inLateZiHour, isTrue);
      expect(bySun.hour.branch, Branch.hai);
      expect(bySun.inLateZiHour, isFalse);
      expect(bySun.chartTime.hour, 22);
      expect(bySun.chartTime.minute, 44);
    });

    test('without a place there is only the clock', () {
      final chart = at(2026, 6, 13, 12, 0, config: const BaziConfig());
      expect(chart.correction, Duration.zero);
    });

    test('the day can be made to turn at midnight by the sun', () {
      // In Surabaya the sun is half an hour ahead of the clock: at 23:40
      // by the clock it is already past midnight by the sun.
      final chart = at(
        2026,
        6,
        13,
        23,
        40,
        longitude: 112.75,
        config: clock.copyWith(ziHourRule: ZiHourRule.trueSolarMidnight),
      );
      final plain = chart.withConfig(clock);
      expect(chart.day, plain.day.step(1));
    });

    test('by midnight by the sun, the hour before it takes the coming '
        "day's stem", () {
      // 12 October 2026 is a 己未 day. Read at the zone's own meridian,
      // the sun is some thirteen minutes ahead of the clock.
      const sun = BaziConfig(ziHourRule: ZiHourRule.trueSolarMidnight);
      BaziChart on(int day, int hour, int minute) =>
          at(2026, 10, day, hour, minute, longitude: 105, config: sun);
      expect(on(12, 0, 23).day.hanzi, '己未');
      expect(on(12, 0, 23).hour.hanzi, '甲子');
      expect(on(12, 21, 43).hour.hanzi, '乙亥');
      expect(on(12, 23, 23).day.hanzi, '己未');
      expect(on(12, 23, 23).hour.hanzi, '丙子');
      expect(on(13, 0, 23).day.hanzi, '庚申');
      expect(on(13, 0, 23).hour.hanzi, '丙子');
      // The split and unified rules agree on that hour.
      for (final rule in [ZiHourRule.split, ZiHourRule.unified]) {
        final chart = on(12, 23, 23).withConfig(sun.copyWith(ziHourRule: rule));
        expect(chart.hour.hanzi, '丙子', reason: '$rule');
      }
    });

    test('by midnight by the sun, the hour is read by the sun as well, '
        'even when the clock is asked for', () {
      // At 00:20 by the clock on 13 October at 95.3 degrees east, the sun
      // has not yet reached midnight: still the 己未 day, in its late zi
      // hour, 丙子, and not the 甲子 that opened it.
      final chart = at(
        2026,
        10,
        13,
        0,
        20,
        longitude: 95.3,
        config: clock.copyWith(ziHourRule: ZiHourRule.trueSolarMidnight),
      );
      expect(chart.day.hanzi, '己未');
      expect(chart.hour.hanzi, '丙子');
      expect(chart.inLateZiHour, isTrue);
      expect(chart.chartTime.hour, 23);
    });
  });

  group('the luck pillars', () {
    test('give the starting age in full, cut short, or to the nearest '
        'year', () {
      final chart = at(2026, 10, 12, 10, 0);
      final exact = chart.luck(male: true);
      expect(exact.rounding, LuckRounding.exact);
      expect(exact.firstAge, exact.startAge.floor());
      final nearest = chart
          .withConfig(
            const BaziConfig(
              timeMode: TimeMode.clock,
              luckRounding: LuckRounding.nearestYear,
            ),
          )
          .luck(male: true);
      expect(nearest.startAge, exact.startAge);
      expect(nearest.firstAge, exact.startAge.round());
    });

    final chart = at(2026, 10, 12, 12, 0);

    test('go forward for a yang year and a man, or a yin year and a woman', () {
      // 2026 is bing, yang; 2025 is yi, yin.
      final yin = at(2025, 10, 12, 12, 0);
      expect(chart.luck(male: true).forward, isTrue);
      expect(chart.luck(male: false).forward, isFalse);
      expect(yin.luck(male: true).forward, isFalse);
      expect(yin.luck(male: false).forward, isTrue);
    });

    test('step through the cycle from the month pillar, stem and branch '
        'together', () {
      expect(chart.month.hanzi, '戊戌');
      expect(chart.luck(male: true).pillars.map((p) => p.hanzi).take(4), [
        '己亥',
        '庚子',
        '辛丑',
        '壬寅',
      ]);
      expect(chart.luck(male: false).pillars.map((p) => p.hanzi).take(4), [
        '丁酉',
        '丙申',
        '乙未',
        '甲午',
      ]);
      expect(chart.luck(male: true).pillars, hasLength(8));
    });

    test('begin at an age counted from the term, three days to a year', () {
      // Forward: to Lidong, 7 November. Back: from Hanlu, 8 October.
      final forward = chart.luck(male: true);
      final days = chart.termAfter.difference(chart.instant).inSeconds / 86400;
      expect(forward.startAge, closeTo(days / 3, 1e-9));
      expect(forward.startAge, closeTo(8.7, 0.1));
      expect(forward.startAgeParts.years, 8);
      final back = chart.luck(male: false);
      expect(back.startAge, closeTo(1.3, 0.1));
      expect(back.startAgeParts.years, 1);
      expect(back.startAgeParts.months, inInclusiveRange(3, 4));

      // Counted to the start of the term's day it comes out a little
      // less, going forward.
      final byDay = chart.withConfig(
        clock.copyWith(luckAnchor: LuckAnchor.termDay),
      );
      expect(byDay.luck(male: true).startAge, lessThan(forward.startAge));
      expect(
        forward.startAge - byDay.luck(male: true).startAge,
        lessThan(1 / 3),
      );
    });
  });

  group('the ten gods', () {
    test('are what each stem is to the self', () {
      expect(
        [for (final stem in Stem.values) TenGod.of(Stem.jia, stem).hanzi],
        ['比肩', '劫財', '食神', '傷官', '偏財', '正財', '七殺', '正官', '偏印', '正印'],
      );
      // For a yin self, alike and unlike change places.
      expect(TenGod.of(Stem.yi, Stem.jia), TenGod.rival);
      expect(TenGod.of(Stem.yi, Stem.geng), TenGod.directOfficer);
      expect(TenGod.of(Stem.gui, Stem.ren), TenGod.rival);
      expect(TenGod.of(Stem.gui, Stem.jia), TenGod.hurtingOfficer);
    });
  });

  group('the branch relations every school agrees on', () {
    String pairs(Branch Function(Branch) of) => {
      for (final branch in Branch.values)
        ([branch.hanzi, of(branch).hanzi]..sort()).join(),
    }.join(' ');

    test('six clashes, each with the branch opposite', () {
      expect(pairs((b) => b.clash).split(' '), hasLength(6));
      expect(Branch.zi.clash, Branch.wu);
      expect(Branch.si.clash, Branch.hai);
    });

    test('six harmonies', () {
      for (final (a, b) in [
        (Branch.zi, Branch.chou),
        (Branch.yin, Branch.hai),
        (Branch.mao, Branch.xu),
        (Branch.chen, Branch.you),
        (Branch.si, Branch.shen),
        (Branch.wu, Branch.wei),
      ]) {
        expect(a.harmony, b);
        expect(b.harmony, a);
      }
    });

    test('four trines of three', () {
      expect(
        [Branch.shen, Branch.zi, Branch.chen].map((b) => b.trine).toSet(),
        {Unsur.air},
      );
      expect([Branch.hai, Branch.mao, Branch.wei].map((b) => b.trine).toSet(), {
        Unsur.kayu,
      });
      expect([Branch.yin, Branch.wu, Branch.xu].map((b) => b.trine).toSet(), {
        Unsur.api,
      });
      expect([Branch.si, Branch.you, Branch.chou].map((b) => b.trine).toSet(), {
        Unsur.logam,
      });
    });
  });
}
