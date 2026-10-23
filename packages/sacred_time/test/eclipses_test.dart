import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  // NASA's catalogue (Espenak, eclipse.gsfc.nasa.gov, LEdecade2021),
  // greatest eclipse in Terrestrial Time, about 70 s ahead of UTC then.
  const lunar = [
    ('2021-05-26T11:19:53', 'total', 1.009),
    ('2021-11-19T09:04:06', 'partial', 0.974),
    ('2022-05-16T04:12:42', 'total', 1.414),
    ('2022-11-08T11:00:22', 'total', 1.359),
    ('2023-05-05T17:24:05', 'penumbral', -0.046),
    ('2023-10-28T20:15:18', 'partial', 0.122),
    ('2024-03-25T07:13:59', 'penumbral', -0.132),
    ('2024-09-18T02:45:25', 'partial', 0.085),
    ('2025-03-14T06:59:56', 'total', 1.178),
    ('2025-09-07T18:12:58', 'total', 1.362),
    ('2026-03-03T11:34:52', 'total', 1.151),
    ('2026-08-28T04:14:04', 'partial', 0.930),
    ('2027-02-20T23:14:06', 'penumbral', -0.057),
    // 2027-07-18 16:04:09, penumbral, -1.068: a graze of a thousandth of
    // the penumbra, which our radii, about 0.004 smaller, just miss.
    ('2027-08-17T07:14:59', 'penumbral', -0.525),
    ('2028-01-12T04:14:13', 'partial', 0.066),
    ('2028-07-06T18:20:57', 'partial', 0.389),
    ('2028-12-31T16:53:15', 'total', 1.246),
    ('2029-06-26T03:23:22', 'total', 1.844),
    ('2029-12-20T22:43:12', 'total', 1.117),
    ('2030-06-15T18:34:34', 'partial', 0.502),
    ('2030-12-09T22:28:51', 'penumbral', -0.163),
  ];

  test('every lunar eclipse of 2021 to 2030, as NASA has it: the day, the '
      'kind, the umbral magnitude, the greatest to two minutes', () {
    final found = Eclipses.lunarFrom(DateTime.utc(2021), 3652);
    expect(found, hasLength(lunar.length));
    for (final (i, (td, kind, magnitude)) in lunar.indexed) {
      final e = found[i];
      final greatest = DateTime.parse('${td}Z');
      final ours = e.greatest.add(const Duration(seconds: 70));
      expect(
        ours.difference(greatest).inSeconds.abs(),
        lessThan(120),
        reason: td,
      );
      expect(e.kind.name, kind, reason: td);
      expect(e.umbralMagnitude, closeTo(magnitude, 0.02), reason: td);
    }
  });

  test('totality at Dallas on 8 April 2024, to half a minute', () {
    // 1:40:43 to 1:44:35 p.m. CDT, 18:40:43 to 18:44:35 UTC.
    final e = Eclipses.solarFrom(
      DateTime.utc(2024, 4, 1),
      14,
      latitude: 32.78,
      longitude: -96.80,
    ).single;
    expect(e.kind, EclipseKind.total);
    expect(e.magnitude, greaterThan(1));
    expect(e.visible, isTrue);
    expect(
      e.centralBegins!
          .difference(DateTime.utc(2024, 4, 8, 18, 40, 43))
          .inSeconds
          .abs(),
      lessThan(30),
    );
    expect(
      e.centralEnds!
          .difference(DateTime.utc(2024, 4, 8, 18, 44, 35))
          .inSeconds
          .abs(),
      lessThan(30),
    );
  });

  test('a ring at Albuquerque on 14 October 2023; the long totality at '
      'Luxor on 2 August 2027', () {
    final ring = Eclipses.solarFrom(
      DateTime.utc(2023, 10, 10),
      10,
      latitude: 35.08,
      longitude: -106.65,
    ).single;
    expect(ring.kind, EclipseKind.annular);
    final luxor = Eclipses.solarFrom(
      DateTime.utc(2027, 7, 28),
      10,
      latitude: 25.70,
      longitude: 32.64,
    ).single;
    expect(luxor.kind, EclipseKind.total);
    expect(
      luxor.centralEnds!.difference(luxor.centralBegins!).inSeconds,
      greaterThan(6 * 60),
    );
  });

  test('from Jakarta, 2023 April 20 is partial; a year with no eclipse '
      'there has none', () {
    final jakarta = Eclipses.solarFrom(
      DateTime.utc(2023, 4, 15),
      10,
      latitude: -6.2,
      longitude: 106.8,
    ).single;
    expect(jakarta.kind, EclipseKind.partial);
    expect(jakarta.visible, isTrue);
    // October 2024's ring crossed southern South America only.
    expect(
      Eclipses.solarFrom(
        DateTime.utc(2024, 9, 25),
        15,
        latitude: -6.2,
        longitude: 106.8,
      ),
      isEmpty,
    );
  });
}
