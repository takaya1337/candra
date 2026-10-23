import 'package:candra/app_shell.dart';
import 'package:candra/main.dart';
import 'package:candra/salat/salat_choice.dart';
import 'package:candra/salat/salat_screen.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:candra/date_picker.dart';
import 'package:candra/glyph_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));
  // A day that is not today, whatever day the tests run on: the screen
  // opens on today's moment and on any other day's noon.
  final now = DateTime.now();
  final date =
      CivilDate(now.year, now.month, now.day) == CivilDate(2026, 10, 20)
      ? CivilDate(2026, 10, 21)
      : CivilDate(2026, 10, 20);
  const offset = Duration(hours: 7);

  setUp(() => SkyPlace.current.value = (latitude: -6.2, longitude: 106.8));
  tearDown(() {
    SkyPlace.current.value = null;
    SalatChoice.method.value = null;
    SalatChoice.madhab.value = Madhab.standard;
    SalatChoice.highLatitude.value = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: language),
        home: SalatScreen(date: date, utcOffset: offset),
      ),
    );
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String name) =>
      tester.widget<Text>(key(name)).data!;

  String clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  testWidgets('lists every time of the day as the reckoning gives it', (
    tester,
  ) async {
    await pump(tester);
    final times = SalatTimes.of(
      date,
      latitude: -6.2,
      longitude: 106.8,
      utcOffset: offset,
    );
    for (final salat in Salat.values) {
      expect(text(tester, 'salat-time-${salat.name}'), clock(times[salat]!));
    }
    // Not today: the dial opens on Subuh, its time to sunrise.
    expect(text(tester, 'salat-name'), 'SUBUH');
    expect(
      text(tester, 'salat-span'),
      '${clock(times[Salat.subuh]!)} – ${clock(times[Salat.terbit]!)}',
    );
  });

  testWidgets('touching the dial chooses the time under the touch', (
    tester,
  ) async {
    await pump(tester);
    final dial = tester.getRect(key('salat-dial'));
    // As wide as the body.
    expect(dial.width, greaterThan(350));
    final radius = dial.shortestSide / 2 * 0.86;
    // Noon is at the bottom; a little past it, clockwise, is Zuhur.
    Future<void> touchAt(double hours) async {
      final angle = hours / 24 * 2 * 3.141592653589793 - 3.141592653589793 / 2;
      await tester.tapAt(dial.center + Offset.fromDirection(angle, radius));
      await tester.pumpAndSettle();
    }

    await touchAt(12.5);
    expect(text(tester, 'salat-name'), 'ZUHUR');
    expect(find.textContaining('the sun past the meridian'), findsOneWidget);
    await touchAt(16);
    expect(text(tester, 'salat-name'), 'ASAR');
    // Just past midnight is still the night's Isya.
    await touchAt(0.5);
    expect(text(tester, 'salat-name'), 'ISYA');
    await touchAt(18.2);
    expect(text(tester, 'salat-name'), 'MAGRIB');
    expect(find.textContaining('The Hijri day begins here'), findsOneWidget);
  });

  testWidgets('a row of the list chooses its time', (tester) async {
    await pump(tester, language: AppLanguage.id);
    await tester.tap(key('salat-row-imsak'));
    await tester.pumpAndSettle();
    expect(text(tester, 'salat-name'), 'IMSAK');
    expect(find.textContaining('Sepuluh menit sebelum Subuh'), findsOneWidget);
  });

  testWidgets('another day from the wheels, and back to today beside the '
      'calendar button', (tester) async {
    await pump(tester);
    // The house's today, beside the menu button.
    final menu = tester.getRect(key('menu-button'));
    final today = tester.getRect(key('today-button'));
    expect(today.left, greaterThan(menu.right));
    expect(today.left, lessThan(menu.right + 24));
    bool lit() => tester.widget<GlyphButton>(key('today-button')).lit;
    // Not today: not lit (the house's today is lit when at today).
    expect(lit(), isFalse);
    await tester.tap(key('salat-panel-date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePicker), findsOneWidget);
    await tester.tap(key('today-button'));
    await tester.pumpAndSettle();
    expect(lit(), isTrue);
    final now = DateTime.now();
    expect(
      find.textContaining(
        Strings(AppLanguage.en)
            .gregorian(CivilDate(now.year, now.month, now.day)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a place it asks for one, and the steps set it', (
    tester,
  ) async {
    SkyPlace.current.value = null;
    await pump(tester);
    expect(key('salat-ask-place'), findsOneWidget);
    expect(key('place-latitude-up'), findsOneWidget);
    await tester.tap(key('place-latitude-down'));
    await tester.pumpAndSettle();
    expect(SkyPlace.current.value, (latitude: -0.1, longitude: 0.0));
    // In the Gulf of Guinea, far from Indonesia: a convention first.
    expect(key('salat-ask-method'), findsOneWidget);
    expect(key('salat-dial'), findsNothing);
  });

  testWidgets('in Indonesia the ministry\'s reckoning, with no choice to '
      'make', (tester) async {
    await pump(tester);
    expect(key('salat-panel-method'), findsNothing);
    expect(key('salat-row-imsak'), findsOneWidget);
    expect(find.text('Subuh'), findsOneWidget);
  });

  testWidgets('abroad it asks for a convention, the region\'s first, and '
      'reckons by the one chosen', (tester) async {
    // London.
    SkyPlace.current.value = (latitude: 51.5, longitude: -0.1);
    await pump(tester);
    expect(key('salat-ask-method'), findsOneWidget);
    expect(key('salat-methods'), findsOneWidget);
    expect(find.text('Muslim World League'), findsOneWidget);
    await tester.tap(key('salat-method-muslimWorldLeague'));
    await tester.pumpAndSettle();
    expect(SalatChoice.method.value, SalatMethod.muslimWorldLeague);
    expect(key('salat-dial'), findsOneWidget);
    // The names used there, and no Imsak.
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
    expect(key('salat-row-imsak'), findsNothing);
    final standard = SalatTimes.of(
      date,
      latitude: 51.5,
      longitude: -0.1,
      utcOffset: offset,
      method: SalatMethod.muslimWorldLeague,
    );
    expect(text(tester, 'salat-time-isya'), clock(standard[Salat.isya]!));

    // Hanafi Asr, from the Method panel.
    await tester.tap(key('salat-panel-method'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      key('salat-madhab'),
      100,
      scrollable: find.descendant(
        of: key('salat-methods'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(key('salat-madhab'));
    await tester.pumpAndSettle();
    expect(SalatChoice.madhab.value, Madhab.hanafi);
    await tester.tap(key('salat-panel-times'));
    await tester.pumpAndSettle();
    final hanafi = SalatTimes.of(
      date,
      latitude: 51.5,
      longitude: -0.1,
      utcOffset: offset,
      method: SalatMethod.muslimWorldLeague,
      madhab: Madhab.hanafi,
    );
    expect(text(tester, 'salat-time-asar'), clock(hanafi[Salat.asar]!));
  });
}
