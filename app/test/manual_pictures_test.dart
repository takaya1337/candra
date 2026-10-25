import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:candra/app_shell.dart';
import 'package:candra/appearance.dart';
import 'package:candra/calendar_system.dart';
import 'package:candra/house.dart';
import 'package:candra/journal/categories_screen.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_file_screen.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/journal/samples.dart';
import 'package:candra/journal/showcase_text.dart';
import 'package:candra/main.dart';
import 'package:candra/menu/colours_screen.dart';
import 'package:candra/menu/manual_screen.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/places/place_screen.dart';
import 'package:candra/reading_screen.dart';
import 'package:candra/reminders/reminder_store.dart';
import 'package:candra/routes.dart';
import 'package:candra/search/search_screen.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/stars/star_catalog.dart';
import 'package:candra/strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// The manual's exhibits (owner, 22 October 2026: "like the shit you
/// encounter at museums"): each feature's screen as the app draws it,
/// with the showcase journal in it, and where each part the manual names
/// stands on it, for the numbered markers.
///
/// Run as it is, it lays out every exhibit in English and dark, and fails
/// if one runs over or a part it marks is not on its screen: so the
/// manual cannot point at a button that has moved.
///
/// `tool/manual_pictures.sh` runs it with
/// `--dart-define=MANUAL_PICTURES=<dir>`, which makes all four versions
/// (English and Indonesian, dark and light) in the app's typefaces and
/// keeps the pictures and `marks.json` in `<dir>`, for the script to turn
/// into the app's assets.
void main() {
  const out = String.fromEnvironment('MANUAL_PICTURES');
  const offset = Duration(hours: 7);
  final today = CivilDate(2026, 10, 22);
  // An iPhone upright, in points; drawn at three pixels a point.
  const size = Size(440, 956);
  const ratio = 3.0;

  final source = File(ShowcaseText.asset).readAsStringSync();

  setUpAll(() async {
    // No debug ribbon on the pictures.
    WidgetsApp.debugAllowBannerOverride = false;
    if (out.isEmpty) return;
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(
          Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
        );
      }
      await loader.load();
    }

    const fonts = '../packages/sm_design/fonts';
    await load('packages/sm_design/IBMPlexMono', [
      for (final face in ['Regular', 'Medium', 'Bold', 'Italic', 'BoldItalic'])
        '$fonts/IBMPlexMono-$face.ttf',
    ]);
    await load('packages/sm_design/JetBrainsMono', [
      '$fonts/JetBrainsMono-Regular.ttf',
      '$fonts/JetBrainsMono-Bold.ttf',
    ]);
    await load('packages/sm_design/NotoSansSymbols', [
      '$fonts/NotoSansSymbols-Planets.ttf',
    ]);
    // The phone draws Chinese in its own font. Here the Mac's Arial
    // Unicode stands in, as the last face tried (a face is chosen by its
    // family, not by what it has, so it takes the sun's sign's place too).
    await load('packages/sm_design/NotoSansSymbols2', [
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    ]);
    Directory(out).createSync(recursive: true);
  });

  setUp(() {
    Manual.preload(source);
    // Yogyakarta, as the store screenshots: never the phone's place.
    SkyPlace.current.value = SkyPlace.rounded(-7.8, 110.4);
  });
  tearDown(() => SkyPlace.current.value = null);

  // What each exhibit shows: the calendar it is under, the screen, what
  // is done on it first, and the parts it marks, by the names the
  // manual's button lines use (manual.<feature>.button.<name>).
  BuildContext home(WidgetTester tester) =>
      tester.element(find.byType(MonthScreen, skipOffstage: false));
  HouseState house(WidgetTester tester) => House.maybeOf(home(tester))!;

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  // What is worked out off the main thread (the stars, the year's
  // searches) finishes only in real time.
  Future<void> wait(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(WidgetTester tester, Room room, WidgetBuilder page) async {
    house(tester).openIn(room, fadeRoute<void>(home(tester), page));
    await tester.pumpAndSettle();
  }

  Future<void> utility(WidgetTester tester, String name) async {
    await tap(tester, 'utilities-button');
    await tap(tester, 'utility-$name');
    await wait(tester);
  }

  final exhibits =
      <
        ManualFeature,
        ({
          CalendarSystem system,
          MonthScreenView view,
          Future<void> Function(WidgetTester tester, JournalStore journal) show,
          Map<String, String> marks,
        })
      >{
        ManualFeature.menu: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) => tap(t, 'menu-button'),
          marks: {'menu': 'menu-button'},
        ),
        ManualFeature.colours: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) async {
            await tap(t, 'menu-button');
            await open(t, Room.menu, (_) => const ColoursScreen());
          },
          marks: {'back': 'colours-restore'},
        ),
        ManualFeature.journalFile: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) async {
            await tap(t, 'menu-button');
            await open(t, Room.menu, (_) => const JournalFileScreen());
          },
          marks: {'share': 'action-share'},
        ),
        ManualFeature.today: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) async {},
          marks: {'today': 'today-button'},
        ),
        ManualFeature.utilities: (
          system: CalendarSystem.gregorian,
          view: MonthScreenView.month,
          show: (t, j) => tap(t, 'utilities-button'),
          marks: {'utilities': 'utilities-button'},
        ),
        ManualFeature.bazi: (
          system: CalendarSystem.chinese,
          view: MonthScreenView.month,
          show: (t, j) async {
            await utility(t, 'bazi');
            // The last of its tabs, built once its row is scrolled to it.
            await t.scrollUntilVisible(
              find.byKey(const ValueKey('bazi-field-options')),
              200,
              scrollable: find.descendant(
                of: find.byKey(const ValueKey('bazi-fields')),
                matching: find.byType(Scrollable),
              ),
            );
            await tap(t, 'bazi-field-options');
          },
          marks: {'import': 'bazi-read', 'journal': 'bazi-export'},
        ),
        ManualFeature.iching: (
          system: CalendarSystem.chinese,
          view: MonthScreenView.month,
          // Its page: the faint 易 and the four ways in.
          show: (t, j) => utility(t, 'iching'),
          marks: {
            'stalks': 'iching-stalks',
            'coins': 'iching-coins',
            'byHand': 'iching-manual',
            'book': 'iching-read',
          },
        ),
        ManualFeature.mangsa: (
          system: CalendarSystem.javanese,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'mangsa'),
          marks: {},
        ),
        ManualFeature.lintang: (
          system: CalendarSystem.javanese,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'lintang'),
          marks: {'planets': 'stars-planets'},
        ),
        ManualFeature.salat: (
          system: CalendarSystem.hijri,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'salat'),
          marks: {'place': 'salat-panel-place'},
        ),
        ManualFeature.hilal: (
          system: CalendarSystem.hijri,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'hilal'),
          marks: {},
        ),
        ManualFeature.ephemeris: (
          system: CalendarSystem.gregorian,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'sky'),
          marks: {},
        ),
        ManualFeature.planets: (
          system: CalendarSystem.gregorian,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'planets'),
          marks: {},
        ),
        ManualFeature.stars: (
          system: CalendarSystem.gregorian,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'stars'),
          marks: {'planets': 'stars-planets'},
        ),
        ManualFeature.light: (
          system: CalendarSystem.gregorian,
          view: MonthScreenView.month,
          show: (t, j) => utility(t, 'light'),
          marks: {'compass': 'light-compass'},
        ),
        ManualFeature.place: (
          system: CalendarSystem.gregorian,
          view: MonthScreenView.month,
          show: (t, j) => open(t, Room.living, (_) => const PlaceScreen()),
          marks: {'search': 'place-query'},
        ),
        ManualFeature.calendar: (
          system: CalendarSystem.javanese,
          view: MonthScreenView.month,
          show: (t, j) async {},
          marks: {'monthButton': 'month-button', 'monthView': 'zoom-button'},
        ),
        ManualFeature.systems: (
          system: CalendarSystem.chinese,
          view: MonthScreenView.month,
          show: (t, j) => tap(t, 'system-label'),
          marks: {'system': 'picker-done'},
        ),
        ManualFeature.reading: (
          system: CalendarSystem.weton,
          view: MonthScreenView.month,
          show: (t, j) => open(
            t,
            Room.living,
            (_) => ReadingScreen(date: today, utcOffset: offset, today: today),
          ),
          marks: {'copy': 'copy-reading', 'saveImage': 'save-reading'},
        ),
        ManualFeature.practice: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) => tap(t, 'practice-button'),
          marks: {'start': 'practice-start'},
        ),
        ManualFeature.reminders: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) => tap(t, 'reminder-button'),
          marks: {
            'reminder': 'reminder-button',
            'add': 'reminder-add',
            'delete': 'delete-card',
          },
        ),
        ManualFeature.journal: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) => tap(t, 'journal-button'),
          marks: {
            'journal': 'journal-button',
            'add': 'new-entry',
            'categories': 'categories',
            'search': 'journal-search',
          },
        ),
        ManualFeature.entry: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) async {
            await tap(t, 'journal-button');
            // The sunrise at Borobudur: a title, words, a quote and a
            // place.
            final entry = j.allEntries().firstWhere(
              (e) => e.place != null,
              orElse: () => j.allEntries().first,
            );
            await open(
              t,
              Room.journal,
              (_) => EntryScreen(
                date: entry.date,
                utcOffset: offset,
                entry: entry,
              ),
            );
          },
          marks: {
            'edit': 'entry-edit',
            'tag': 'entry-tags',
            'delete': 'entry-delete',
          },
        ),
        ManualFeature.categories: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) async {
            await tap(t, 'journal-button');
            await open(t, Room.journal, (_) => const CategoriesScreen());
          },
          marks: {'add': 'category-add'},
        ),
        ManualFeature.search: (
          system: CalendarSystem.weton,
          view: MonthScreenView.day,
          show: (t, j) async {
            await tap(t, 'journal-button');
            await open(
              t,
              Room.journal,
              (_) => SearchScreen(date: today, utcOffset: offset, today: today),
            );
          },
          marks: {'monthView': 'search-view'},
        ),
      };

  test('every feature has an exhibit', () {
    expect(exhibits.keys.toSet(), ManualFeature.values.toSet());
  });

  final versions = out.isEmpty
      ? [(AppLanguage.en, Brightness.dark)]
      : [
          for (final language in AppLanguage.values)
            for (final side in [Brightness.dark, Brightness.light])
              (language, side),
        ];
  // Where each part stands on each picture, as a share of its width and
  // height: 'en-dark' -> 'journal' -> 'add' -> [x, y, width, height].
  final marks = <String, Map<String, Map<String, List<double>>>>{};

  for (final (language, side) in versions) {
    final version = '${language.name}-${side.name}';
    for (final MapEntry(key: feature, value: exhibit) in exhibits.entries) {
      testWidgets('$version: ${feature.name}', (tester) async {
        tester.view.physicalSize = size * ratio;
        tester.view.devicePixelRatio = ratio;
        tester.view.padding = const FakeViewPadding(top: 62 * ratio);
        tester.view.viewPadding = const FakeViewPadding(top: 62 * ratio);
        addTearDown(tester.view.reset);

        final root = Directory.systemTemp.createTempSync('manual');
        addTearDown(() => root.deleteSync(recursive: true));
        final journal = JournalStore(FileJournalStorage.open(root));
        addTearDown(journal.dispose);
        final reminders = ReminderStore(utcOffset: offset);
        final text = ShowcaseText.parse(source, language);
        Samples.showcase(
          journal,
          root,
          offset,
          today: today,
          now: 21 * 60 + 30,
          text: text,
        );
        Samples.showcaseReminders(
          reminders,
          journal,
          today: today,
          text: text,
          utcOffset: offset,
        );

        // The stars are read once and kept; read again here, in real
        // time, so this test's clock can see them.
        if (feature == ManualFeature.stars ||
            feature == ManualFeature.lintang) {
          StarCatalog.reset();
          Galaxy.reset();
          await tester.runAsync(StarCatalog.load);
          await tester.runAsync(Galaxy.load);
        }

        await tester.pumpWidget(
          CalendarJournalApp(
            controller: SystemController()..value = exhibit.system,
            language: LanguageController(saved: language),
            appearance: AppearanceController(saved: side),
            journal: journal,
            reminders: reminders,
            home: MonthScreen(
              today: today,
              utcOffset: offset,
              lockedView: exhibit.view,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await exhibit.show(tester, journal);
        await tester.pumpAndSettle();

        final found = <String, List<double>>{};
        for (final MapEntry(key: name, value: key) in exhibit.marks.entries) {
          final part = find.byKey(ValueKey(key)).hitTestable();
          expect(part, findsWidgets, reason: '${feature.name}: $key');
          // Its centre and its size, as shares of the picture.
          final rect = tester.getRect(part.first);
          found[name] = [
            rect.center.dx / size.width,
            rect.center.dy / size.height,
            rect.width / size.width,
            rect.height / size.height,
          ];
        }
        (marks[version] ??= {})[feature.name] = found;

        if (out.isNotEmpty) {
          await tester.runAsync(() async {
            final image = await captureImage(
              find.byType(CalendarJournalApp).evaluate().single,
            );
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('$out/$version').createSync(recursive: true);
            File('$out/$version/${feature.name}.png')
                .writeAsBytesSync(png!.buffer.asUint8List());
          });
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  tearDownAll(() {
    if (out.isEmpty) return;
    File('$out/marks.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(marks));
  });
}
