import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

import 'kemenag_schedules.dart';

void main() {
  for (final (name, latitude, longitude, hours, days) in kemenagSchedules) {
    test('$name: within a minute of the ministry, nine in ten exactly', () {
      var times = 0;
      var exact = 0;
      for (final MapEntry(key: day, value: line) in days.entries) {
        final [y, m, d] = day.split('-').map(int.parse).toList();
        final ours = SalatTimes.of(
          CivilDate(y, m, d),
          latitude: latitude,
          longitude: longitude,
          utcOffset: Duration(hours: hours),
        );
        final theirs = [
          for (final hm in line.split(' '))
            int.parse(hm.substring(0, 2)) * 60 + int.parse(hm.substring(3)),
        ];
        for (final (i, salat) in Salat.values.indexed) {
          final off = ours[salat]! - theirs[i];
          expect(off.abs(), lessThanOrEqualTo(1), reason: '$day $salat');
          times++;
          if (off == 0) exact++;
        }
      }
      expect(exact / times, greaterThan(0.88), reason: '$exact of $times');
    });
  }

  test('imsak is ten minutes before subuh', () {
    final times = SalatTimes.of(
      CivilDate(2026, 10, 14),
      latitude: -6.2,
      longitude: 106.8,
      utcOffset: const Duration(hours: 7),
    );
    expect(times[Salat.subuh]! - times[Salat.imsak]!, 10);
  });

  test('a northern midsummer has no isya', () {
    final times = SalatTimes.of(
      CivilDate(2026, 6, 21),
      latitude: 60.2,
      longitude: 24.9,
      utcOffset: const Duration(hours: 3),
    );
    expect(times[Salat.isya], isNull);
    expect(times[Salat.subuh], isNull);
    expect(times[Salat.zuhur], isNotNull);
  });
}
