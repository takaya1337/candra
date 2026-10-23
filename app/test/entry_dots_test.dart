import 'package:candra/calendar_system.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/month_grid.dart';
import 'package:candra/pixel_snap.dart';
import 'package:candra/strings.dart';
import 'package:candra/system_months.dart';
import 'package:candra/year_grid.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

void main() {
  const palette = [
    Color(0xFF000001),
    Color(0xFF000002),
    Color(0xFF000003),
    Color(0xFF000004),
    Color(0xFF000005),
    Color(0xFF000006),
    Color(0xFF000007),
    Color(0xFF000008),
    Color(0xFF000009),
    Color(0xFF00000A),
  ];
  final today = CivilDate(2026, 10, 11);

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SmTheme(
        data: SmThemeData.dusk,
        child: Center(child: SizedBox(width: 411, height: 500, child: child)),
      ),
    ),
  );

  testWidgets('a day cell shows at most four dots, the earliest first, along '
      'its bottom edge', (tester) async {
    await pump(
      tester,
      MonthGrid(
        span: SystemMonth(CivilDate(2026, 10, 1), 31),
        system: CalendarSystem.gregorian,
        today: today,
        selected: today,
        onSelect: (_) {},
        dotsOf: (date) => switch (date.day) {
          11 => palette,
          12 => palette.sublist(0, 2),
          _ => const [],
        },
      ),
    );

    final cells = tester.widget<EntryDots>(find.byType(EntryDots)).cells;
    // October 2026 starts on a Thursday: the 1st is the fourth cell.
    List<Color> dotsIn(String day) => cells[int.parse(day) + 2].colors;

    expect(dotsIn('11'), palette.sublist(0, 4));
    expect(dotsIn('12'), palette.sublist(0, 2));
    expect(dotsIn('13'), isEmpty);
    expect(cells, hasLength(42));
    expect(cells[0].inMonth, isFalse);
    expect(cells[3].inMonth, isTrue);
    expect(MonthGrid.maxDots, 4);

    // The dots take nothing from the number: it sits where it does in a
    // cell without any.
    expect(
      tester.getCenter(find.text('11')).dy -
          tester.getCenter(find.text('18')).dy,
      moreOrLessEquals(
        tester.getCenter(find.text('13')).dy -
            tester.getCenter(find.text('20')).dy,
      ),
    );
  });

  test('dots stand in the order of their colours round the wheel', () {
    List<int> order(List<int> colours) => [
      for (final category in byHue([
        for (final colour in colours)
          JournalCategory(id: '$colour', name: '$colour', colorIndex: colour),
      ]))
        category.colorIndex,
    ];

    expect(order([14, 2, 18, 8]), [2, 8, 14, 18]);
    expect(order([5]), [5]);
    expect(order([20, 3]), [3, 20]);
    // The wheel joins up: 23 and 0 are neighbours, so the row starts
    // after the widest gap and keeps them together.
    expect(order([0, 23, 11, 12]), [11, 12, 23, 0]);
    expect(order([1, 22, 23, 2]), [22, 23, 1, 2]);
    // The two ends are the pair furthest apart.
    expect(order([0, 6, 12, 20]), [20, 0, 6, 12]);
  });

  test('a dot is moved onto the screen\'s own pixels', () {
    // At 3.5 pixels to the unit, with the grid starting at 100.3 on the
    // screen: wherever in the grid a dot is put, it lands on a whole pixel.
    for (final local in [0.0, 7.31, 54.77, 288.123]) {
      final snapped = PixelSnap.position(local, 100.3, 3.5);
      final pixel = (100.3 + snapped) * 3.5;
      expect(pixel, moreOrLessEquals(pixel.roundToDouble(), epsilon: 1e-6));
      // And by less than a pixel.
      expect((snapped - local).abs(), lessThan(1 / 3.5));
    }
    // A dot is a whole, even number of pixels across; a gap a whole number.
    expect(PixelSnap.radius(4, 3.5) * 2 * 3.5, 14);
    expect(PixelSnap.radius(4, 2.625) * 2 * 2.625, 10);
    expect(PixelSnap.length(7.53, 3.5) * 3.5, 26);
  });

  testWidgets('a month of the year grid shows at most eight dots', (
    tester,
  ) async {
    await pump(
      tester,
      YearGrid(
        months: YearGrid.gregorian(2026),
        monthLabels: [
          for (final name in const Strings(AppLanguage.en).monthNames)
            name.substring(0, 3),
        ],
        system: CalendarSystem.gregorian,
        today: today,
        selected: today,
        strings: const Strings(AppLanguage.en),
        onTapMonth: (_) {},
        dotsOf: (month) => switch (month) {
          10 => palette,
          3 => palette.sublist(0, 1),
          _ => const [],
        },
      ),
    );

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(YearGrid),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter
            as dynamic;
    final dots = painter.dots as List<List<Color>>;
    expect(dots, hasLength(12));
    expect(dots[9], palette.sublist(0, 8));
    expect(dots[2], palette.sublist(0, 1));
    expect(dots[0], isEmpty);
    expect(YearGrid.maxDots, 8);
  });
}
