import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

import 'bazi_oracle_fixtures.dart';

/// Holds the engine against two other implementations, lunar_python and
/// sxtwl, over thousands of charts. Neither is an authority: where they
/// part from this library the test names the reason.
void main() {
  const beijing = Duration(hours: 8);

  BaziChart at(int y, int mo, int d, int h, int mi, ZiHourRule rule) =>
      BaziChart.at(
        DateTime.utc(y, mo, d, h, mi).subtract(beijing),
        utcOffset: beijing,
        config: BaziConfig(timeMode: TimeMode.clock, ziHourRule: rule),
      );

  String four(BaziChart chart) =>
      '${chart.year.hanzi}${chart.month.hanzi}'
      '${chart.day.hanzi}${chart.hour.hanzi}';

  test('every node term from 1900 to 2100 falls within the minute of '
      'sxtwl\'s', () {
    var worst = Duration.zero;
    for (final (index, y, mo, d, h, mi, s) in oracleNodeTerms) {
      final theirs = DateTime.utc(y, mo, d, h, mi, s).subtract(beijing);
      // Their index 1 is Xiaohan at 285 degrees, and each next node is
      // thirty degrees on.
      final longitude = (285 + 15.0 * (index - 1)) % 360;
      final ours = Sun.nextCrossing(
        theirs.subtract(const Duration(days: 2)),
        longitude,
      );
      final apart = ours.difference(theirs).abs();
      if (apart > worst) worst = apart;
      expect(
        apart,
        lessThan(const Duration(seconds: 60)),
        reason: 'term $index of $y-$mo-$d',
      );
    }
    printOnFailure('worst: $worst');
  });

  test('nayin and the void branches of all sixty pairs agree with '
      'lunar_python', () {
    // That library writes simplified characters.
    const traditional = {
      '炉': '爐',
      '剑': '劍',
      '锋': '鋒',
      '头': '頭',
      '涧': '澗',
      '蜡': '蠟',
      '杨': '楊',
      '雳': '靂',
      '长': '長',
      '灯': '燈',
      '驿': '驛',
      '钗': '釵',
      '钏': '釧',
    };
    expect(oracleCycle, hasLength(60));
    for (final (i, (pair, nayin, empty)) in oracleCycle.indexed) {
      final pillar = Pillar.ofCycle(i);
      expect(pillar.hanzi, pair);
      expect(
        pillar.nayin,
        nayin.split('').map((c) => traditional[c] ?? c).join(),
      );
      expect(pillar.voidBranches.map((b) => b.hanzi).join(), empty);
      expect(pillar.nayinElement.index, '木火土金水'.indexOf(nayin[2]));
    }
  });

  for (final kind in ['any', 'term', 'zi', 'newyear']) {
    test('charts agree with lunar_python: $kind', () {
      var count = 0;
      for (final (k, y, mo, d, h, mi, keeps, next) in oracleCharts) {
        if (k != kind) continue;
        count++;
        final when = '$y-$mo-$d $h:$mi';
        expect(
          four(at(y, mo, d, h, mi, ZiHourRule.split)),
          keeps,
          reason: '$when, the day kept',
        );
        expect(
          four(at(y, mo, d, h, mi, ZiHourRule.unified)),
          next,
          reason: '$when, the day given on',
        );
      }
      expect(count, greaterThan(900));
    });
  }
}
