import 'package:sacred_time/sacred_time.dart';
import 'package:test/test.dart';

void main() {
  String mangsa(int y, int m, int d) =>
      PranataMangsa.of(CivilDate(y, m, d)).toString();

  group('the court\'s rule', () {
    test('year 1 opens on 22 June 1855 and closes on 21 June 1856', () {
      expect(mangsa(1855, 6, 22), '1 Kasa 1');
      expect(mangsa(1856, 6, 21), '41 Sada 1');
      expect(mangsa(1856, 6, 22), '1 Kasa 2');
      expect(PranataMangsa.supports(CivilDate(1855, 6, 21)), isFalse);
      expect(() => PranataMangsa.of(CivilDate(1855, 6, 21)), throwsRangeError);
    });

    test('the lengths are 41 23 24 25 27 43 43 26 25 24 23 41', () {
      expect(
        [for (final m in Mangsa.values) m.days],
        [41, 23, 24, 25, 27, 43, 43, 26, 25, 24, 23, 41],
      );
      expect(Mangsa.values.fold(0, (sum, m) => sum + m.days), 365);
    });

    // The first days as the primbon's table and the lengths give them.
    test('each mangsa opens on its date', () {
      const starts = [
        (6, 22),
        (8, 2),
        (8, 25),
        (9, 18),
        (10, 13),
        (11, 9),
        (12, 22),
        (2, 3),
        (3, 1),
        (3, 26),
        (4, 19),
        (5, 12),
      ];
      for (final year in [1, 45, 46, 145, 172, 173, 174]) {
        for (final m in Mangsa.values) {
          final start = PranataMangsa.startOf(year, m);
          expect((start.month, start.day), starts[m.index], reason: '$m $year');
          final date = PranataMangsa.of(start);
          expect(date.mangsa, m);
          expect(date.day, 1);
          expect(date.year, year);
        }
      }
    });

    test('Kawolu takes the leap day: 26 days, 27 in a long year', () {
      expect(mangsa(2026, 2, 28), '26 Kawolu 171');
      expect(mangsa(2026, 3, 1), '1 Kasanga 171');
      expect(PranataMangsa.of(CivilDate(2026, 2, 28)).isLong, isFalse);
      expect(mangsa(2028, 2, 29), '27 Kawolu 173');
      expect(mangsa(2028, 3, 1), '1 Kasanga 173');
      final long = PranataMangsa.of(CivilDate(2027, 6, 22));
      expect(long.isLong, isTrue);
      expect(PranataMangsa.of(CivilDate(2028, 2, 3)).length, 27);
      // 1900 was not a leap year.
      expect(mangsa(1900, 2, 28), '26 Kawolu 45');
      expect(mangsa(1900, 3, 1), '1 Kasanga 45');
    });

    test('every day of four years is in one mangsa, in order', () {
      var date = CivilDate(2024, 6, 22);
      var last = PranataMangsa.of(date);
      for (var i = 0; i < 1461; i++) {
        date = date.addDays(1);
        final now = PranataMangsa.of(date);
        if (now.day == 1) {
          expect(last.day, last.length);
          expect(now.mangsa.index, (last.mangsa.index + 1) % 12);
        } else {
          expect(now.day, last.day + 1);
          expect(now.mangsa, last.mangsa);
        }
        last = now;
      }
    });
  });

  group('seasons', () {
    test('four seasons of three mangsa', () {
      for (final season in MangsaSeason.values) {
        expect(Mangsa.values.where((m) => m.season == season).length, 3);
      }
    });

    test('Daldjoeni\'s four: 82, 99, 86 and 98 days', () {
      int days(MangsaPhase phase) => Mangsa.values
          .where((m) => m.phase == phase)
          .fold(0, (sum, m) => sum + m.days);
      expect(days(MangsaPhase.terang), 82);
      expect(days(MangsaPhase.semplah), 99);
      expect(days(MangsaPhase.udan), 86);
      expect(days(MangsaPhase.pangarepArep), 98);
    });
  });

  // The primbon says the mangsa are cut by the noon shadow of a person
  // standing between Merapi and Lawu, measured in their own feet: 4, 3,
  // 2, 1, 0, 1, 2, 1, 0, 1, 2, 3. Checked here against the sun: with a
  // person 6.6 of their own feet tall, every opening day's shadow comes
  // to the stated whole number, and falls the stated way.
  group('the shadow the mangsa are cut by', () {
    const feetTall = 6.6;

    test('each mangsa opens at its length of shadow', () {
      for (final m in Mangsa.values) {
        final shadow = PranataMangsa.noonShadow(PranataMangsa.startOf(172, m));
        expect(
          (shadow.abs() * feetTall).round(),
          m.pecak,
          reason: '${m.label}: ${shadow * feetTall} feet',
        );
        if (m.shadowSouth != null) {
          expect(shadow > 0, m.shadowSouth, reason: m.label);
        }
      }
    });

    test('the sun is overhead as Kalima and Kasanga open', () {
      for (final m in [Mangsa.kalima, Mangsa.kasanga]) {
        final shadow = PranataMangsa.noonShadow(PranataMangsa.startOf(172, m));
        expect(shadow.abs(), lessThan(0.01));
      }
    });
  });
}
