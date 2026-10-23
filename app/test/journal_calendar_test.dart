import 'package:candra/app_shell.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/month_grid.dart';
import 'package:candra/parts.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 11);
  Finder key(String name) => find.byKey(ValueKey(name));

  testWidgets('the journal has its own calendar, behind its date button: '
      'the month with a dot for every category written in each day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    final store = JournalStore();
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        journal: store,
        home: JournalScreen(date: day, utcOffset: offset, today: day),
      ),
    );
    await tester.pumpAndSettle();
    expect(key('journal-calendar'), findsNothing);

    await tester.tap(key('journal-date'));
    await tester.pumpAndSettle();
    // In the main body, over the date wheels in the lower panel.
    final calendar = tester.getRect(key('journal-calendar'));
    final line = tester.getRect(key('panel-separator'));
    expect(calendar.bottom, lessThanOrEqualTo(line.top));
    expect(key('picker-day'), findsOneWidget);

    final grid = tester.widget<MonthGrid>(find.byType(MonthGrid));
    expect((grid.year, grid.month), (2026, 10));
    expect(grid.selected, day);
    // Sunday the 11th in the stand-in journal: ritual, plant log, dream,
    // in the order of their colours round the wheel.
    expect(grid.dotsOf!(day), [
      categoryPalette[18],
      categoryPalette[2],
      categoryPalette[8],
    ]);
    // Thursdays have nothing.
    expect(grid.dotsOf!(CivilDate(2026, 10, 15)), isEmpty);

    // Tapping a day goes to it; the wheels follow.
    await tester.tap(
      find.descendant(of: key('journal-calendar'), matching: find.text('20')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TopBarButton>(key('journal-date')).label,
      '20 October 2026',
    );
    expect(
      tester.widget<MonthGrid>(find.byType(MonthGrid)).selected,
      CivilDate(2026, 10, 20),
    );

    // The date button, tapped again, puts the folders back, on that day.
    await tester.tap(key('journal-date'));
    await tester.pumpAndSettle();
    expect(key('journal-calendar'), findsNothing);
    expect(key('day-strip'), findsOneWidget);
  });
}
