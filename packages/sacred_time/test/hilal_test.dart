import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

DateTime _jd(double jd) => DateTime.fromMillisecondsSinceEpoch(
  ((jd - 2440587.5) * 86400000).round(),
  isUtc: true,
);

double _dms(int d, int m, double s) => d.sign * (d.abs() + m / 60 + s / 3600);

void main() {
  // Bosscha Observatory, Lembang (6°49′50″ S, 107°37′00″ E), its press
  // releases for Ramadan and Syawal 1446 and 1447 (WIB, UTC+7).
  group('against Bosscha Observatory\'s releases', () {
    const lat = -(6 + 49 / 60 + 50 / 3600), lon = 107 + 37 / 60;
    const wib = Duration(hours: 7);
    CrescentEvening at(CivilDate d) =>
        Hilal.evening(d, latitude: lat, longitude: lon, utcOffset: wib)!;
    String clock(DateTime t) {
      final w = t.add(wib);
      return '${w.hour.toString().padLeft(2, '0')}:'
          '${w.minute.toString().padLeft(2, '0')}:'
          '${w.second.toString().padLeft(2, '0')}';
    }

    void near(DateTime t, String expected, {int seconds = 5}) {
      final [h, m, s] = expected.split(':').map(int.parse).toList();
      final want = DateTime.utc(t.year, t.month, t.day, h, m, s).subtract(wib);
      // The day of [t] in WIB, for evenings that cross no midnight.
      final w = t.add(wib);
      final expectedAt = DateTime.utc(
        w.year,
        w.month,
        w.day,
        h,
        m,
        s,
      ).subtract(wib);
      expect(
        t.difference(expectedAt).inSeconds.abs(),
        lessThanOrEqualTo(seconds),
        reason: '${clock(t)} against $expected ($want)',
      );
    }

    test('28 February 2025: above the MABIMS height, short of its '
        'elongation here', () {
      final e = at(CivilDate(2025, 2, 28));
      near(e.conjunction, '07:44:50', seconds: 60);
      near(e.sunset, '18:09:06');
      near(e.moonset!, '18:28:39');
      expect(e.elongation, closeTo(_dms(6, 0, 40.1), 10 / 3600));
      expect(e.topocentricElongation, closeTo(_dms(5, 4, 37.6), 10 / 3600));
      expect(e.altitude, closeTo(_dms(3, 50, 33.4), 20 / 3600));
      expect(e.moonAzimuth, closeTo(_dms(264, 2, 41), 30 / 3600));
      expect(e.sunAzimuth, closeTo(_dms(262, 3, 55), 30 / 3600));
      expect(e.age.inMinutes, closeTo(10 * 60 + 24, 2));
      expect(e.mabims, isFalse);
      expect(e.wujudulHilal, isTrue);
    });

    test('29 March 2025: the moon sets before the sun, the new moon '
        'still to come', () {
      final e = at(CivilDate(2025, 3, 29));
      near(e.conjunction, '17:57:50', seconds: 60);
      near(e.sunset, '17:55:50');
      near(e.moonset!, '17:49:19');
      expect(e.altitude, closeTo(_dms(-2, 23, 43.4), 20 / 3600));
      expect(e.elongation, closeTo(_dms(1, 3, 39.1), 10 / 3600));
      expect(e.age.isNegative, isTrue);
      expect(e.lag!.isNegative, isTrue);
      expect(e.bestTime, isNull);
      expect(e.yallop, isNull);
      expect(e.mabims, isFalse);
      expect(e.wujudulHilal, isFalse);
    });

    test('17 February 2026 and 19 March 2026', () {
      final feb = at(CivilDate(2026, 2, 17));
      near(feb.conjunction, '19:01:09', seconds: 60);
      near(feb.sunset, '18:12:41');
      near(feb.moonset!, '18:09:00');
      expect(feb.altitude, closeTo(_dms(-1, 41, 45.7), 20 / 3600));
      expect(feb.elongation, closeTo(_dms(1, 3, 4.4), 10 / 3600));
      expect(feb.mabims, isFalse);

      final mar = at(CivilDate(2026, 3, 19));
      near(mar.conjunction, '08:23:28', seconds: 60);
      near(mar.sunset, '18:00:51');
      near(mar.moonset!, '18:10:50');
      expect(mar.altitude, closeTo(_dms(1, 34, 7.5), 20 / 3600));
      expect(mar.elongation, closeTo(_dms(5, 40, 44.7), 10 / 3600));
      expect(mar.topocentricElongation, closeTo(_dms(5, 9, 21.7), 10 / 3600));
      expect(mar.mabims, isFalse);
      expect(mar.wujudulHilal, isTrue);
    });
  });

  // Yallop, NAO Technical Note 69 (1997), table 4.
  test('Yallop\'s q, against his own table', () {
    final no278 = Hilal.evening(
      CivilDate(1990, 2, 25),
      latitude: 35.6,
      longitude: -83.5,
      utcOffset: const Duration(hours: -5),
    )!;
    expect(no278.lag!.inSeconds / 60, closeTo(38.3, 0.5));
    expect(no278.yallopArcv, closeTo(8.5, 0.06));
    expect(no278.yallopWidth, closeTo(0.18, 0.01));
    expect(no278.q, closeTo(-0.222, 0.005));
    expect(no278.yallop, YallopClass.d);
    // His age is at the best time.
    expect(
      no278.bestTime!.difference(no278.conjunction).inMinutes / 60,
      closeTo(14.8, 0.1),
    );

    final no145 = Hilal.evening(
      CivilDate(1978, 1, 9),
      latitude: 30.0,
      longitude: -90.2,
      utcOffset: const Duration(hours: -6),
    )!;
    expect(no145.lag!.inSeconds / 60, closeTo(58.8, 0.5));
    expect(no145.yallopWidth, closeTo(0.40, 0.01));
    expect(no145.q, closeTo(0.312, 0.005));
    expect(no145.yallop, YallopClass.a);
  });

  // Odeh, Experimental Astronomy 18 (2004), table VI (W there in
  // seconds of arc).
  test('Odeh\'s V, against his own table', () {
    final o520 = Hilal.at(_jd(2452348.168), latitude: 30.4, longitude: 35.5);
    expect(o520.oArcv, closeTo(4.8, 0.06));
    expect(o520.oWidth * 60, closeTo(7, 1));
    expect(Hilal.odehV(o520.oArcv, o520.oWidth), closeTo(-1.60, 0.05));

    final o547 = Hilal.at(_jd(2452496.206), latitude: 30.4, longitude: 35.5);
    expect(o547.oArcv, closeTo(10.5, 0.06));
    expect(o547.oWidth * 60, closeTo(23, 1));
    expect(Hilal.odehV(o547.oArcv, o547.oWidth), closeTo(5.67, 0.05));

    // Hill, 9 January 1978, the evening of Yallop's no. 145.
    final o147 = Hilal.evening(
      CivilDate(1978, 1, 9),
      latitude: 36.0,
      longitude: -79.8,
      utcOffset: const Duration(hours: -5),
    )!;
    expect(o147.odehArcv, closeTo(11.0, 0.06));
    expect(o147.v, closeTo(5.78, 0.1));
    expect(o147.odeh, OdehZone.a);
  });

  test('the classes and zones at their bounds', () {
    CrescentEvening with_({double? q, double? v}) => CrescentEvening(
      conjunction: DateTime.utc(2026),
      sunset: DateTime.utc(2026, 1, 1, 12),
      moonset: DateTime.utc(2026, 1, 1, 13),
      altitude: 5,
      apparentAltitude: 5,
      sunAzimuth: 250,
      moonAzimuth: 252,
      elongation: 8,
      topocentricElongation: 8,
      illumination: 0.01,
      upperEdge: 6,
      bestTime: DateTime.utc(2026, 1, 1, 12, 27),
      yallopArcv: 0,
      yallopWidth: 0,
      q: q,
      odehArcv: 0,
      odehWidth: 0,
      v: v,
    );
    expect(with_(q: 0.217).yallop, YallopClass.a);
    expect(with_(q: 0.216).yallop, YallopClass.b);
    expect(with_(q: -0.014).yallop, YallopClass.c);
    expect(with_(q: -0.160).yallop, YallopClass.d);
    expect(with_(q: -0.232).yallop, YallopClass.e);
    expect(with_(q: -0.293).yallop, YallopClass.f);
    expect(with_(v: 5.65).odeh, OdehZone.a);
    expect(with_(v: 2).odeh, OdehZone.b);
    expect(with_(v: -0.96).odeh, OdehZone.c);
    expect(with_(v: -0.97).odeh, OdehZone.d);
    expect(with_().mabims, isTrue);
  });

  test('the new moon to the second, nearest the instant', () {
    // Bosscha: 17 February 2026, 19:01:09 WIB = 12:01:09 UT; the
    // Maklumat of Muhammadiyah gives 12:01:09 UTC.
    final c = Hilal.conjunctionNear(DateTime.utc(2026, 2, 10));
    expect(
      c.difference(DateTime.utc(2026, 2, 17, 12, 1, 9)).inSeconds.abs(),
      lessThanOrEqualTo(60),
    );
  });

  test('the light sweep agrees with the evening', () {
    final e = Hilal.evening(
      CivilDate(2025, 2, 28),
      latitude: -6.8,
      longitude: 107.6,
      utcOffset: const Duration(hours: 7),
    )!;
    final s = Hilal.atSunset(
      CivilDate(2025, 2, 28),
      latitude: -6.8,
      longitude: 107.6,
      utcOffset: const Duration(hours: 7),
    )!;
    expect(s.altitude, e.altitude);
    expect(s.elongation, e.elongation);
  });
}
