import 'dart:io';

import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  test('every one of NOAA\'s WMM2025 test values: the components to a '
      'nanotesla, the declination to a hundredth of a degree', () {
    final rows = File('test/fixtures/wmm/WMM2025_TestValues.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'));
    var count = 0;
    for (final line in rows) {
      final f = line.trim().split(RegExp(r'\s+')).map(double.parse).toList();
      final field = MagneticField.at(f[2], f[3], height: f[1], year: f[0]);
      final where = line.trim();
      expect(field.declination, closeTo(f[4], 0.01), reason: where);
      expect(field.north, closeTo(f[7], 1), reason: where);
      expect(field.east, closeTo(f[8], 1), reason: where);
      expect(field.down, closeTo(f[9], 1), reason: where);
      count++;
    }
    expect(count, 100);
  });

  test('in Java the needle points within a degree of true north', () {
    final field = MagneticField.at(-7.8, 110.4, year: 2026.8);
    expect(field.declination.abs(), lessThan(1.5));
  });
}
