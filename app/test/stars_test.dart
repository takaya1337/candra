import 'dart:math' as math;
import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/main.dart';
import 'package:candra/planets/planet_look.dart';
import 'package:candra/sky/sky_screen.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/stars/star_catalog.dart';
import 'package:candra/stars/javanese_stars.dart';
import 'package:candra/stars/star_screen.dart';
import 'package:candra/strings.dart';
import 'package:candra/utilities.dart';
import 'package:candra/calendar_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// The star map: its catalogue, read whole, and its screen.
void main() {
  final catalog = StarCatalog.parse(
    File('assets/stars/hyg_v44_naked_eye.csv').readAsStringSync(),
    File('assets/stars/constellations.json').readAsStringSync(),
  );

  test('the catalogue holds the naked-eye sky, brightest first', () {
    expect(catalog.length, 8920);
    expect(catalog.name[0], 'Sirius');
    expect(catalog.rightAscension[0], closeTo(101.28722, 1e-5));
    expect(catalog.declination[0], closeTo(-16.71612, 1e-5));
    for (var i = 1; i < catalog.length; i++) {
      expect(
        catalog.magnitude[i],
        greaterThanOrEqualTo(catalog.magnitude[i - 1]),
      );
    }
    expect(catalog.magnitude[catalog.length - 1], lessThanOrEqualTo(6.5));
    expect(catalog.figures, hasLength(89));
    expect(catalog.figures.where((f) => f.id == 'Ori').single.name, 'Orion');
  });

  test('a star without a name is called by its Greek letter and '
      'constellation', () {
    final i = List.generate(catalog.length, (i) => i).firstWhere(
      (i) =>
          catalog.name[i].isEmpty &&
          catalog.bayer[i].startsWith('Gam') &&
          !catalog.bayer[i].contains('-'),
    );
    expect(catalog.labelOf(i), 'γ ${catalog.constellation[i]}');
    final numbered = List.generate(
      catalog.length,
      (i) => i,
    ).firstWhere((i) => catalog.name[i].isEmpty && catalog.bayer[i] == 'Gam-2');
    expect(catalog.labelOf(numbered), 'γ² Vel');
  });

  test('a star is found by its name, its letter, its constellation or its '
      'number, names first, brightest first', () {
    expect(catalog.labelOf(catalog.find('sirius').first), 'Sirius');
    expect(catalog.labelOf(catalog.find('Betel').first), 'Betelgeuse');
    // Orion's Latin name finds its stars, Rigel (the brightest) first.
    final orion = catalog.find('orion');
    expect(orion, isNotEmpty);
    expect(catalog.constellation[orion.first], 'Ori');
    expect(catalog.labelOf(orion.first), 'Rigel');
    // The Bright Star number of Sirius.
    expect(catalog.labelOf(catalog.find('HR 2491').single), 'Sirius');
    expect(catalog.find('zzzz'), isEmpty);
    expect(catalog.find('  '), isEmpty);
  });

  test('the bright stars are the named ones, brightest first', () {
    final bright = catalog.brightNamed();
    expect(catalog.labelOf(bright.first), 'Sirius');
    expect(bright.every((i) => catalog.name[i].isNotEmpty), isTrue);
    expect(bright.every((i) => catalog.magnitude[i] <= 2.0), isTrue);
    expect(bright.length, greaterThan(30));
  });

  test('the Gregorian system has the ephemeris, the planets, the star map '
      'and Light', () {
    expect(Utility.of(CalendarSystem.gregorian), [
      Utility.sky,
      Utility.planets,
      Utility.stars,
      Utility.light,
    ]);
  });

  testWidgets('the map opens on the sky of the place, and a touch on a '
      'star reads it', (tester) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
    addTearDown(() => SkyPlace.current.value = null);
    StarCatalog.reset();
    await tester.runAsync(StarCatalog.load);

    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: StarScreen(
          date: CivilDate(2026, 1, 15),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Star map'), findsOneWidget);
    expect(find.byKey(const ValueKey('stars-dome')), findsOneWidget);
    expect(find.byKey(const ValueKey('stars-hint')), findsOneWidget);

    // Sirius at nine in the evening of 15 January, from Jakarta, is high
    // in the east: find it on the dome and touch it.
    final sky = StarSky.at(
      DateTime.utc(2026, 1, 15, 14),
      latitude: -6.2,
      longitude: 106.8,
    );
    final sirius = sky.place(101.28722, -16.71612);
    expect(sirius.altitude, greaterThan(20));
    final dome = tester.getRect(find.byKey(const ValueKey('stars-dome')));
    final radius = dome.shortestSide / 2 - 18;
    final r = radius * (90 - sirius.altitude) / 90;
    final a = sirius.azimuth * math.pi / 180;
    final at = dome.center + Offset(r * math.sin(a), -r * math.cos(a));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-star-name')), findsOneWidget);
    expect(find.text('Sirius'), findsWidgets);

    // Found by name: the bar takes the words, the panel the matches.
    await tester.drag(
      find.byKey(const ValueKey('stars-panels')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-panel-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-query-bar')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('stars-query')), 'Betel');
    await tester.pumpAndSettle();
    final betelgeuse = catalog.find('Betel').first;
    await tester.tap(find.byKey(ValueKey('stars-found-$betelgeuse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-query-bar')), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stars-star-name'))).data,
      'Betelgeuse',
    );

    // The bright stars, chosen from a list.
    await tester.drag(
      find.byKey(const ValueKey('stars-panels')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-panel-bright')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-bright')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stars-bright-0')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stars-star-name'))).data,
      'Sirius',
    );
    // Read where the list was; back closes the reading before the map,
    // and a second time it is read again and closed again the same way.
    expect(find.byKey(const ValueKey('stars-bright-reading')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-bright')), findsOneWidget);
    expect(find.byKey(const ValueKey('stars-bright-reading')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stars-bright-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-bright-reading')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-bright')), findsOneWidget);
    expect(find.byKey(const ValueKey('stars-bright-reading')), findsNothing);
    expect(find.text('Star map'), findsOneWidget);
  });

  test('the Javanese system has the mangsa and Lintang Jawa', () {
    expect(Utility.of(CalendarSystem.javanese), [
      Utility.mangsa,
      Utility.lintang,
    ]);
  });

  test('every Javanese figure\'s stars are in the catalogue', () {
    for (final f in javaneseFigures) {
      for (final hip in [
        ...f.stars,
        for (final (a, b) in f.lines) ...[a, b],
      ]) {
        expect(catalog.byHip(hip), isNotNull, reason: '${f.id} HIP $hip');
      }
      if (f.figure != null) {
        expect(catalog.figures.any((c) => c.id == f.figure), isTrue);
      }
    }
    // Waluku is the Belt and the sword with Rigel and Saiph; Betelgeuse,
    // a wound on the ploughman's foot, is not of it.
    final waluku = javaneseFigures.firstWhere((f) => f.id == 'waluku');
    expect(waluku.stars, containsAll([25930, 26311, 26727, 24436, 27366]));
    expect(waluku.stars, isNot(contains(27989)));
    // Banyakangrem is the Coalsack, a patch beside Crux; Scorpius is
    // Klapa Doyong, Antares in its trunk.
    final goose = javaneseFigures.firstWhere((f) => f.id == 'banyakangrem');
    expect(goose.patch, isNotNull);
    expect(goose.figure, isNull);
    final palm = javaneseFigures.firstWhere((f) => f.id == 'klapadoyong');
    expect(catalog.labelOf(catalog.byHip(80763)!), 'Antares');
    expect(palm.stars, contains(80763));
    expect(
      catalog.labelOf(
        catalog.byHip(
          javaneseFigures
              .firstWhere((f) => f.id == 'badaknyempal')
              .stars
              .single,
        )!,
      ),
      'Sirius',
    );
    // Waluku is marked by its middle Belt star.
    final alnilam = catalog.byHip(26311)!;
    expect(catalog.labelOf(alnilam), 'Alnilam');
    expect(
      catalog.rightAscension[alnilam],
      closeTo(walukuMark.rightAscension, 0.001),
    );
  });

  test('Waluku\'s year at Yogyakarta: risen near Kasa, set near Kapitu', () {
    final w = WalukuYear.work(2026, -7.80, 110.36, const Duration(hours: 7));
    expect(w.kasa, CivilDate(2026, 6, 22));
    expect(w.kapitu, CivilDate(2026, 12, 22));
    expect((w.rises!.dayNumber - w.kasa.dayNumber).abs(), lessThan(15));
    expect((w.sets!.dayNumber - w.kapitu.dayNumber).abs(), lessThan(15));
  });

  testWidgets('on an iPhone or iPad the search keeps its keyboard as its '
      'bar comes to be drawn over the glass', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
    addTearDown(() => SkyPlace.current.value = null);
    StarCatalog.reset();
    await tester.runAsync(StarCatalog.load);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: StarScreen(
          date: CivilDate(2026, 1, 15),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('stars-panels')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-panel-search')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    final field = tester.state(find.byType(EditableText));
    tester.testTextInput.log.clear();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(UiKitView), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.clearClient')),
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Lintang Jawa lists the figures, draws the one touched, and '
      'sets Waluku against the mangsa', (tester) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: -7.8, longitude: 110.36);
    addTearDown(() => SkyPlace.current.value = null);
    StarCatalog.reset();
    await tester.runAsync(StarCatalog.load);

    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: StarScreen(
          date: CivilDate(2026, 7, 1),
          utcOffset: const Duration(hours: 7),
          javanese: true,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Lintang Jawa'), findsOneWidget);
    expect(find.byKey(const ValueKey('lintang-figures')), findsOneWidget);
    expect(find.byKey(const ValueKey('stars-panel-bright')), findsNothing);
    expect(find.text('Waluku'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('lintang-waluku')));
    await tester.pumpAndSettle();
    final dome = tester.widget<StarDome>(
      find.byKey(const ValueKey('stars-dome')),
    );
    expect(dome.javanese, isTrue);
    expect(dome.figure, 'waluku');

    await tester.tap(find.byKey(const ValueKey('stars-panel-mangsa')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 3)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lintang-mangsa')), findsOneWidget);
    expect(find.text('KASA OPENS'), findsOneWidget);
    expect(find.text('KAPITU OPENS'), findsOneWidget);
  });

  test('the view magnifies about a point, and keeps within the dome', () {
    const centre = Offset(200, 200);
    const v = StarView(2, Offset(0.5, 0));
    // The point it is about is drawn at the centre.
    expect(v.place(const Offset(300, 200), centre, 200), centre);
    // Twice as far from it as on the whole dome.
    expect(
      v.place(const Offset(400, 200), centre, 200),
      const Offset(400, 200),
    );
    // The window stays on the sphere: its centre within twice the
    // horizon's reach, less the window's own.
    expect(const StarView(2, Offset(3, 0)).kept.pan, const Offset(1.5, 0));
    expect(
      StarView.lerp(StarView.whole, v, 0.5),
      const StarView(1.5, Offset(0.25, 0)),
    );
    final galaxies = Galaxy.parse(
      File('assets/stars/galaxies.tsv').readAsStringSync(),
    );
    expect(galaxies.length, greaterThan(100));
    expect(galaxies[2].name, 'Andromeda Galaxy');
    expect(galaxies[2].designations, 'M 31 · NGC 224');
  });

  testWidgets('a bright star chosen is brought to the centre, nearer; a '
      'constellation and a galaxy are chosen from their lists', (tester) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
    addTearDown(() => SkyPlace.current.value = null);
    StarCatalog.reset();
    await tester.runAsync(StarCatalog.load);
    Galaxy.reset();
    await tester.runAsync(Galaxy.load);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: StarScreen(
          date: CivilDate(2026, 1, 15),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    StarDome dome() =>
        tester.widget<StarDome>(find.byKey(const ValueKey('stars-dome')));
    expect(dome().view.value, StarView.whole);

    await tester.drag(
      find.byKey(const ValueKey('stars-panels')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-panel-bright')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-bright-0')));
    await tester.pumpAndSettle();
    // Sirius, at the centre, two and a half times nearer.
    final sky = StarSky.at(
      DateTime.utc(2026, 1, 15, 14),
      latitude: -6.2,
      longitude: 106.8,
    );
    final sirius = sky.place(101.28722, -16.71612);
    final at = SkyDome.project(Offset.zero, 1, sirius.altitude, sirius.azimuth);
    expect(dome().view.value.zoom, 2.5);
    expect((dome().view.value.pan - at).distance, lessThan(0.01));

    // Orion, chosen from the constellations.
    await tester.drag(
      find.byKey(const ValueKey('stars-panels')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-panel-constellations')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stars-constellation-Ori')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('stars-constellations')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('stars-constellation-Ori')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-constellation-Ori')));
    await tester.pumpAndSettle();
    expect(dome().constellation, 'Ori');

    // The galaxies, brightest first; one chosen is marked.
    await tester.tap(find.byKey(const ValueKey('stars-panel-galaxies')));
    await tester.pumpAndSettle();
    expect(find.text('Large Magellanic Cloud'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stars-galaxy-0')));
    await tester.pumpAndSettle();
    expect(dome().galaxy, 0);
    expect(dome().view.value.zoom, 3);

    // The search finds galaxies by designation, and constellations.
    await tester.drag(
      find.byKey(const ValueKey('stars-panels')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-panel-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('stars-query')), 'm31');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-found-gal-2')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('stars-query')), 'orio');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-found-con-Ori')), findsOneWidget);

    // Polaris never rises at Jakarta: found, it is still brought to the
    // centre, below the horizon.
    await tester.enterText(
      find.byKey(const ValueKey('stars-query')),
      'Polaris',
    );
    await tester.pumpAndSettle();
    final polaris = catalog.find('Polaris').first;
    await tester.tap(find.byKey(ValueKey('stars-found-$polaris')));
    await tester.pumpAndSettle();
    expect(dome().view.value.pan.distance, greaterThan(1));

    // The strip under the dome puts the whole sky back first.
    await tester.tap(find.byKey(const ValueKey('stars-strip')));
    await tester.pumpAndSettle();
    expect(dome().view.value, StarView.whole);
  });

  Future<void> openMap(
    WidgetTester tester, {
    required CivilDate date,
    bool javanese = false,
    int? minute,
  }) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
    addTearDown(() => SkyPlace.current.value = null);
    PlanetLook.shown.value = true;
    addTearDown(() => PlanetLook.shown.value = true);
    StarCatalog.reset();
    await tester.runAsync(StarCatalog.load);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: StarScreen(
          date: date,
          utcOffset: const Duration(hours: 7),
          javanese: javanese,
          minute: minute,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  // Where a planet stands on the whole dome, at [instant], from Jakarta.
  Offset onDome(WidgetTester tester, Body body, DateTime instant) {
    final p = SkyNow.planet(body, instant, latitude: -6.2, longitude: 106.8);
    expect(p.altitude, greaterThan(10));
    final dome = tester.getRect(find.byKey(const ValueKey('stars-dome')));
    final radius = dome.shortestSide / 2 - 18;
    final r = radius * (90 - p.altitude) / 90;
    final a = p.azimuth * math.pi / 180;
    return dome.center + Offset(r * math.sin(a), -r * math.cos(a));
  }

  testWidgets('the planets stand among the stars, a touch reads one, and '
      'the button hides them', (tester) async {
    await openMap(tester, date: CivilDate(2026, 1, 15));
    // Jupiter at nine in the evening of 15 January 2026, high over Jakarta.
    final jupiter = onDome(tester, Body.jupiter, DateTime.utc(2026, 1, 15, 14));
    await tester.tapAt(jupiter);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stars-planet-name'))).data,
      '♃  Jupiter',
    );
    expect(find.text('Evening sky, east of the sun'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stars-planets')));
    await tester.pumpAndSettle();
    expect(PlanetLook.shown.value, isFalse);
    expect(find.byKey(const ValueKey('stars-planet-name')), findsNothing);
    await tester.tapAt(jupiter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-planet-name')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stars-planets')));
    await tester.pumpAndSettle();
    expect(PlanetLook.shown.value, isTrue);

    // In the search the bar is the words' (the house's gives way to it),
    // and the cross with nothing to clear puts the keyboard away.
    await tester.drag(
      find.byKey(const ValueKey('stars-panels')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stars-panel-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stars-query-bar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('menu-button')).hitTestable(),
      findsNothing,
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byKey(const ValueKey('stars-query-clear')));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byKey(const ValueKey('stars-query-bar')), findsOneWidget);
  });

  testWidgets('on the Javanese sky Venus is Panjer Sore in the evening', (
    tester,
  ) async {
    // Seven in the evening of 15 July 2026: Venus, east of the sun all
    // that summer, high in the west over Jakarta.
    await openMap(
      tester,
      date: CivilDate(2026, 7, 15),
      javanese: true,
      minute: 19 * 60,
    );
    await tester.tapAt(
      onDome(tester, Body.venus, DateTime.utc(2026, 7, 15, 12)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stars-planet-name'))).data,
      'Panjer Sore · Venus',
    );
    expect(find.textContaining('Gericke and Roorda'), findsOneWidget);
  });
}
