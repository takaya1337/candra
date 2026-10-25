import 'dart:math';

import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  group('the coins', () {
    test('three backs are nine, three faces six, and the rest by the '
        'count', () {
      expect(const CoinThrow([true, true, true]).value, LineValue.oldYang);
      expect(const CoinThrow([false, false, false]).value, LineValue.oldYin);
      expect(const CoinThrow([true, false, false]).value, LineValue.youngYang);
      expect(const CoinThrow([true, true, false]).value, LineValue.youngYin);
    });

    test('six and nine come once in eight, seven and eight three times', () {
      final random = Random(1);
      final seen = <LineValue, int>{};
      const throws = 80000;
      for (var i = 0; i < throws; i++) {
        final value = Yijing.throwCoins(random).value;
        seen[value] = (seen[value] ?? 0) + 1;
      }
      expect(seen[LineValue.oldYin]! / throws, closeTo(1 / 8, 0.006));
      expect(seen[LineValue.oldYang]! / throws, closeTo(1 / 8, 0.006));
      expect(seen[LineValue.youngYang]! / throws, closeTo(3 / 8, 0.008));
      expect(seen[LineValue.youngYin]! / throws, closeTo(3 / 8, 0.008));
    });
  });

  // 朱熹, 筮儀: "一變所餘之䇿 ... 通掛一之䇿不五則九"; "二變 ... 不四
  // 則八"; and thirty-six, thirty-two, twenty-eight or twenty-four left
  // for the old yang, the young yin, the young yang and the old yin.
  group('the stalks', () {
    test('the first change lays aside five or nine, the others four or '
        'eight, however the stalks are parted', () {
      final random = Random(2);
      for (var i = 0; i < 20000; i++) {
        final line = Yijing.countStalks(random);
        expect(line.changes.length, 3);
        expect(line.changes[0].before, 49);
        expect([5, 9], contains(line.changes[0].removed));
        expect([4, 8], contains(line.changes[1].removed));
        expect([4, 8], contains(line.changes[2].removed));
        for (final change in line.changes) {
          expect(change.left, greaterThan(0));
          expect(change.right, greaterThan(1));
          expect(change.left + change.right, change.before);
        }
        expect([24, 28, 32, 36], contains(line.changes.last.after));
        expect(line.value.number * 4, line.changes.last.after);
      }
    });

    test('nine comes three times in sixteen, six once, seven five times '
        'and eight seven', () {
      final random = Random(3);
      final seen = <LineValue, int>{};
      const lines = 160000;
      for (var i = 0; i < lines; i++) {
        final value = Yijing.countStalks(random).value;
        seen[value] = (seen[value] ?? 0) + 1;
      }
      expect(seen[LineValue.oldYin]! / lines, closeTo(1 / 16, 0.006));
      expect(seen[LineValue.oldYang]! / lines, closeTo(3 / 16, 0.008));
      expect(seen[LineValue.youngYang]! / lines, closeTo(5 / 16, 0.008));
      expect(seen[LineValue.youngYin]! / lines, closeTo(7 / 16, 0.008));
    });
  });

  group('a hexagram as cast', () {
    test('the changing lines turn, the others stay', () {
      const cast = YijingCast([
        LineValue.oldYang,
        LineValue.youngYang,
        LineValue.youngYin,
        LineValue.oldYin,
        LineValue.youngYang,
        LineValue.youngYin,
      ]);
      expect(cast.primary, [true, true, false, false, true, false]);
      expect(cast.changing, [0, 3]);
      expect(cast.relating, [false, true, false, true, true, false]);
    });
  });
}
