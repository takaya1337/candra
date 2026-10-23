import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

import 'solar_term_fixtures.dart';

void main() {
  test('every published term crossing is found to the minute', () {
    var worst = Duration.zero;
    for (final (longitude, published) in solarTermFixtures) {
      final found = Sun.nextCrossing(
        published.subtract(const Duration(days: 20)),
        longitude.toDouble(),
      );
      // Published to the minute, so the true instant is within thirty
      // seconds of it; a further half minute is allowed the engine.
      final off = found.difference(published.add(const Duration(seconds: 30)));
      if (off.abs() > worst) worst = off.abs();
      expect(
        off.abs(),
        lessThan(const Duration(seconds: 60)),
        reason: '$longitude° published $published, found $found',
      );
    }
    // ignore: avoid_print
    print('worst miss of ${solarTermFixtures.length}: ${worst.inSeconds} s');
  });

  test('a crossing is found from either side, and from itself', () {
    final lichun = Sun.nextCrossing(DateTime.utc(2026, 1, 1), 315);
    expect(Sun.previousCrossing(DateTime.utc(2026, 3, 1), 315), lichun);
    expect(Sun.nextCrossing(lichun, 315), lichun);
    expect(Sun.previousCrossing(lichun, 315), lichun);
    // A second later it is next year's.
    final after = Sun.nextCrossing(lichun.add(const Duration(seconds: 1)), 315);
    expect(after.year, 2027);
    expect(
      Sun.apparentLongitudeAt(Sun.julianDayOf(lichun)),
      closeTo(315, 2e-5),
    );
  });

  test('the twelve nodes of a year come in order, about a month apart', () {
    var at = DateTime.utc(2026, 1, 1);
    for (var node = 0; node < 12; node++) {
      final next = Sun.nextCrossing(at, (285 + node * 30) % 360);
      final gap = next.difference(at).inHours / 24;
      expect(gap, node == 0 ? closeTo(4, 1) : inInclusiveRange(29, 32));
      at = next;
    }
    expect(at.year, 2026);
    expect(at.month, 12);
  });

  test('the equation of time runs between its known extremes', () {
    double at(int month, int day) => Sun.equationOfTimeAt(
      Sun.julianDayOf(DateTime.utc(2026, month, day, 12)),
    );
    expect(at(2, 11), closeTo(-14.2, 0.3));
    expect(at(11, 3), closeTo(16.4, 0.3));
    // Near nothing four times a year.
    expect(at(4, 15).abs(), lessThan(0.5));
    expect(at(6, 13).abs(), lessThan(0.5));
    expect(at(9, 1).abs(), lessThan(0.5));
    expect(at(12, 25).abs(), lessThan(0.5));
  });
}
