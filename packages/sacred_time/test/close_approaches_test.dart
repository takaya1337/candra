import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  test('the great conjunction of Jupiter and Saturn, 21 December 2020: '
      '6.1 minutes of arc, about 18:20 UT', () {
    final found = CloseApproaches.within(
      DateTime.utc(2020, 12, 15),
      12,
      latitude: -6.2,
      longitude: 106.8,
    );
    final great = found.singleWhere(
      (c) => c.first == Body.jupiter && c.second == Body.saturn,
    );
    expect(
      great.closest.difference(DateTime.utc(2020, 12, 21, 18, 20)).inMinutes,
      inInclusiveRange(-30, 30),
    );
    expect(great.separation * 60, closeTo(6.1, 0.2));
    // From Jakarta, low in the west after sunset.
    expect(great.seen, isNotNull);
    expect(great.height, greaterThan(5));
  });

  test('Venus and Jupiter half a degree apart, 1 to 2 March 2023', () {
    final found = CloseApproaches.within(
      DateTime.utc(2023, 2, 25),
      10,
      latitude: -6.2,
      longitude: 106.8,
    );
    final pair = found.singleWhere(
      (c) => c.first == Body.venus && c.second == Body.jupiter,
    );
    expect(pair.closest.isAfter(DateTime.utc(2023, 3, 1)), isTrue);
    expect(pair.closest.isBefore(DateTime.utc(2023, 3, 3)), isTrue);
    expect(pair.separation, closeTo(0.5, 0.05));
  });

  test('the moon beside a planet is within 3°, a planet hidden by the '
      'sun\'s glare is never seen', () {
    final found = CloseApproaches.within(
      DateTime.utc(2020, 12, 1),
      40,
      latitude: -6.2,
      longitude: 106.8,
    );
    for (final c in found) {
      expect(
        c.separation,
        lessThanOrEqualTo(
          c.first == Body.moon
              ? CloseApproaches.moonWithin
              : CloseApproaches.planetsWithin,
        ),
      );
    }
    final mercury = found.firstWhere(
      (c) => c.first == Body.moon && c.second == Body.mercury,
    );
    expect(mercury.seen, isNull);
  });
}
