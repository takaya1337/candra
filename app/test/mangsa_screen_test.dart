import 'package:candra/app_shell.dart';
import 'package:candra/house.dart';
import 'package:candra/main.dart';
import 'package:candra/mangsa/mangsa_screen.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));

  Future<void> pump(
    WidgetTester tester, {
    CivilDate? date,
    AppLanguage language = AppLanguage.en,
    Size size = const Size(1440, 3040),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: language),
        home: MangsaScreen(date: date ?? CivilDate(2026, 10, 13)),
      ),
    );
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String name) =>
      tester.widget<Text>(key(name)).data!;

  /// Touches the wheel on its rim, [turn] of the way round from the top.
  Future<void> touch(WidgetTester tester, double turn) async {
    final rect = tester.getRect(key('mangsa-wheel'));
    final radius = rect.shortestSide / 2 * 0.86;
    final angle = Offset.fromDirection(
      turn * 2 * 3.141592653589793 - 3.141592653589793 / 2,
      radius,
    );
    await tester.tapAt(rect.center + angle);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the mangsa of the day, with its candra in Javanese '
      'and in words', (tester) async {
    await pump(tester);
    expect(text(tester, 'mangsa-name'), 'KALIMA');
    expect(text(tester, 'mangsa-count'), 'Day 1 of 27');
    expect(text(tester, 'mangsa-candra'), 'Pancuran mas sumawur ing jagad');
    expect(
      find.text('A golden fountain scatters over the world'),
      findsOneWidget,
    );
    expect(find.text('Year 172'), findsOneWidget);
    expect(find.text('13 Oct – 8 Nov'), findsOneWidget);
    expect(find.text('The first rains.'), findsOneWidget);
  });

  testWidgets('touching an arc of the wheel reads that mangsa, and the '
      'wheel does not move', (tester) async {
    await pump(tester);
    final wheel = tester.getRect(key('mangsa-wheel'));
    // As wide as the body.
    expect(wheel.width, greaterThan(350));
    // Just past the top: Kasa, which opens the year.
    await touch(tester, 0.02);
    expect(text(tester, 'mangsa-name'), 'KASA');
    expect(text(tester, 'mangsa-count'), '41 days');
    expect(text(tester, 'mangsa-candra'), 'Sotya murca saking embanan');
    expect(find.text('22 Jun – 1 Aug'), findsOneWidget);
    // Half way round is 22 December, less a day: the end of Kanem.
    await touch(tester, 0.49);
    expect(text(tester, 'mangsa-name'), 'KANEM');
    await touch(tester, 0.51);
    expect(text(tester, 'mangsa-name'), 'KAPITU');
    expect(tester.getRect(key('mangsa-wheel')), wheel);
    // The hub is not the wheel.
    await tester.tapAt(wheel.center);
    await tester.pumpAndSettle();
    expect(text(tester, 'mangsa-name'), 'KAPITU');
  });

  testWidgets('Kawolu has 27 days in a long year', (tester) async {
    await pump(tester, date: CivilDate(2028, 2, 29));
    expect(text(tester, 'mangsa-name'), 'KAWOLU');
    expect(text(tester, 'mangsa-count'), 'Day 27 of 27');
    expect(find.text('3 Feb – 29 Feb'), findsOneWidget);
  });

  testWidgets('speaks Indonesian, and keeps the Javanese', (tester) async {
    await pump(tester, language: AppLanguage.id);
    expect(text(tester, 'mangsa-candra'), 'Pancuran mas sumawur ing jagad');
    expect(find.text('Pancuran emas tersebar di jagad'), findsOneWidget);
    expect(text(tester, 'mangsa-count'), 'Hari ke-1 dari 27');
    expect(find.text('Tahun 172'), findsOneWidget);
  });

  testWidgets('every mangsa fits, upright and on its side, in both '
      'languages', (tester) async {
    for (final size in const [Size(1440, 3040), Size(3040, 1440)]) {
      for (final language in AppLanguage.values) {
        await pump(tester, language: language, size: size);
        for (var i = 0; i < 12; i++) {
          final start = PranataMangsa.startOf(172, Mangsa.values[i]);
          final turn =
              (start.dayNumber - CivilDate(2026, 6, 22).dayNumber + 2) / 365;
          await touch(tester, turn);
          expect(
            text(tester, 'mangsa-name'),
            Mangsa.values[i].label.toUpperCase(),
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('a day before 1855 has no mangsa', (tester) async {
    await pump(tester, date: CivilDate(1850, 1, 1));
    expect(key('mangsa-wheel'), findsNothing);
    // The page still stands, under its name, and is left as any is: by
    // going back, the house's bar over it.
    expect(find.text('Pranata mangsa'), findsOneWidget);
    expect(find.byType(RoomBar), findsOneWidget);
    expect(key('menu-button').hitTestable(), findsOneWidget);
  });
}
