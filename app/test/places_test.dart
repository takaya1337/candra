import 'dart:io';
import 'dart:typed_data';

import 'package:candra/app_shell.dart';
import 'package:candra/main.dart';
import 'package:candra/place_editor.dart';
import 'package:candra/places/kecamatan_outlines.dart';
import 'package:candra/places/place_catalog.dart';
import 'package:candra/places/place_screen.dart';
import 'package:candra/places/world_map.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = PlaceCatalog.parse(
    File('assets/places/places.tsv').readAsStringSync(),
  );
  Finder key(String name) => find.byKey(ValueKey(name));

  test('Indonesia to the kecamatan, each in its kabupaten or kota', () {
    final ciputat = catalog.find('ciputat').first;
    expect(catalog.name[ciputat], 'Ciputat');
    expect(catalog.area[ciputat], contains('Kota Tangerang Selatan, Banten'));
    final kuta = catalog.find('Kuta').first;
    expect(catalog.area[kuta], contains('Kabupaten Badung, Bali'));
    // A kabupaten by a word of its name.
    expect(
      catalog.find('bogor').map((i) => catalog.name[i]),
      containsAll(['Kota Bogor', 'Kabupaten Bogor']),
    );
    expect(catalog.length, greaterThan(40000));
  });

  test('the world by its towns, accents or none, the largest first abroad', () {
    final london = catalog.find('london', indonesiaFirst: false).first;
    expect(catalog.name[london], 'London');
    expect(catalog.country[london], 'GB');
    final paulo = catalog.find('sao paulo', indonesiaFirst: false).first;
    expect(catalog.name[paulo], 'São Paulo');
    expect(catalog.find('zzzzqq'), isEmpty);
  });

  test('the named place nearest a point', () {
    final near = catalog.nearest(-6.31, 106.72, limit: 1).single;
    expect(catalog.name[near], 'Ciputat');
    expect(catalog.nearest(-50, -140, within: 0.3), isEmpty);
  });

  test('the world outline reads as rings of degrees', () {
    final bytes = File('assets/places/world.bin').readAsBytesSync();
    final rings = WorldOutline.parse(ByteData.sublistView(bytes));
    expect(rings.length, greaterThan(1000));
    for (final ring in rings) {
      for (var k = 0; k < ring.length; k += 2) {
        expect(ring[k].abs(), lessThanOrEqualTo(180));
        expect(ring[k + 1].abs(), lessThanOrEqualTo(90));
      }
    }
  });

  final outlines = KecamatanOutlines.parse(
    ByteData.sublistView(File('assets/places/kecamatan.bin').readAsBytesSync()),
  );

  test('every kecamatan has an outline, its named point inside it', () {
    final rows = {for (final k in outlines) k.row};
    final kecamatan = [
      for (var i = 0; i < catalog.length; i++)
        if (catalog.area[i].startsWith('Kecamatan')) i,
    ];
    expect(kecamatan.length, greaterThan(7000));
    expect(rows, containsAll(kecamatan));
    expect(rows.length, kecamatan.length);
    for (final k in outlines) {
      // The catalogue keeps a hundredth of a degree: the point may fall
      // just over the edge of the smallest, so test it as written.
      final lat = catalog.latitude[k.row], lon = catalog.longitude[k.row];
      final grown = k.box.inflate(0.006);
      expect(
        grown.contains(Offset(lon, lat)),
        isTrue,
        reason: catalog.name[k.row],
      );
    }
  });

  test('a point in Indonesia falls in its own kecamatan', () {
    KecamatanOutline? at(double lat, double lon) {
      KecamatanOutline? found;
      for (final k in outlines) {
        if (k.holds(lon, lat) &&
            (found == null ||
                k.box.width * k.box.height <
                    found.box.width * found.box.height)) {
          found = k;
        }
      }
      return found;
    }

    String name(double lat, double lon) => catalog.name[at(lat, lon)!.row];
    // Monas, the Gedung Sate, Malioboro, Ubud's palace.
    expect(name(-6.1754, 106.8272), 'Gambir');
    expect(name(-6.9025, 107.6188), 'Bandung Wetan');
    expect(name(-7.7926, 110.3658), 'Gedongtengen');
    expect(name(-8.5069, 115.2625), 'Ubud');
    // Out at sea, none.
    expect(at(-5.0, 110.0), isNull);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    addTearDown(() => SkyPlace.current.value = null);
    PlaceCatalog.reset();
    KecamatanOutlines.reset();
    await tester.runAsync(PlaceCatalog.load);
    await tester.runAsync(KecamatanOutlines.load);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: home,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('found by name, a touch sets the place; a touch on the map '
      'sets it there', (tester) async {
    SkyPlace.current.value = (latitude: -6.2, longitude: 106.8);
    await pump(tester, const PlaceScreen());
    expect(key('place-map'), findsOneWidget);
    // Near the pin, with no words.
    expect(key('place-list'), findsOneWidget);

    await tester.enterText(key('place-query'), 'Ciputat');
    await tester.pumpAndSettle();
    final ciputat = catalog.find('Ciputat').first;
    await tester.tap(key('place-row-$ciputat'));
    await tester.pumpAndSettle();
    expect(SkyPlace.current.value, (latitude: -6.3, longitude: 106.7));
    expect(find.textContaining('near Ciputat'), findsOneWidget);

    // The map is centred on the place: a touch to the right, in
    // Indonesia, picks the kecamatan there and names it.
    final map = tester.getRect(key('place-map'));
    await tester.tapAt(map.center + const Offset(10, 0));
    await tester.pumpAndSettle();
    final moved = SkyPlace.current.value!;
    expect(moved.longitude, greaterThan(106.7));
    expect(moved.latitude, closeTo(-6.3, 0.2));
    final picked = PlaceCatalog.picked!;
    expect(picked.at, moved);
    expect(catalog.area[picked.index], startsWith('Kecamatan'));
    expect(
      find.textContaining('near ${catalog.name[picked.index]}'),
      findsOneWidget,
    );
  });

  testWidgets('a touch abroad puts the place where it fell', (tester) async {
    SkyPlace.current.value = (latitude: 51.5, longitude: -0.1);
    await pump(tester, const PlaceScreen());
    final map = tester.getRect(key('place-map'));
    await tester.tapAt(map.center + const Offset(0, 60));
    await tester.pumpAndSettle();
    final moved = SkyPlace.current.value!;
    expect(moved.longitude, closeTo(-0.1, 0.05));
    expect(moved.latitude, lessThan(51.5));
  });

  testWidgets('the place editor names the place nearest and opens the '
      'finder', (tester) async {
    SkyPlace.current.value = (latitude: -6.3, longitude: 106.7);
    await pump(
      tester,
      Builder(
        builder: (context) => ColoredBox(
          color: const Color(0xFF000000),
          child: PlaceEditor(strings: Strings.of(context)),
        ),
      ),
    );
    expect(find.textContaining('near '), findsOneWidget);
    await tester.tap(key('place-find'));
    await tester.pumpAndSettle();
    expect(key('place-map'), findsOneWidget);
  });
}
