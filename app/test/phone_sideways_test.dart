import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:candra/app_shell.dart';
import 'package:candra/bazi/bazi_screen.dart';
import 'package:candra/calendar_system.dart';
import 'package:candra/bazi/bazi_tables.dart';
import 'package:candra/hilal/hilal_screen.dart';
import 'package:candra/journal/categories_screen.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_file_screen.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/light/light_screen.dart';
import 'package:candra/main.dart';
import 'package:candra/mangsa/mangsa_screen.dart';
import 'package:candra/menu/colours_screen.dart';
import 'package:candra/menu/essay_screen.dart';
import 'package:candra/menu/manual_screen.dart';
import 'package:candra/journal/showcase_text.dart';
import 'package:candra/menu/menu_screen.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/places/place_screen.dart';
import 'package:candra/planets/planets_screen.dart';
import 'package:candra/practice/practice_screen.dart';
import 'package:candra/reading_screen.dart';
import 'package:candra/reminders/reminder_screen.dart';
import 'package:candra/reminders/reminders_screen.dart';
import 'package:candra/salat/salat_screen.dart';
import 'package:candra/search/search_screen.dart';
import 'package:candra/sky/sky_screen.dart';
import 'package:candra/stars/star_screen.dart';
import 'package:candra/strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// A phone on its side (the Pixel 4 XL, 869 x 411 points): every screen
/// is laid out whole, nothing running over, with the keyboard down and,
/// where something is typed, up.
///
/// `flutter test test/phone_sideways_test.dart --dart-define=PICTURES=dir`
/// also keeps a picture of each, in the app's own typefaces, in `dir`.
void main() {
  const pictures = String.fromEnvironment('PICTURES');
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 15);
  // The Pixel 4 XL on its side, at its 3.5 pixels a point, with its
  // status bar and gesture bar.
  const ratio = 3.5;
  const size = Size(3040, 1440);
  // A phone's keyboard on its side, in points.
  const keyboard = 200.0;

  setUp(() {
    Manual.preload(File(ShowcaseText.asset).readAsStringSync());
    Manual.preloadMarks(File(Manual.marksAsset).readAsStringSync());
  });

  setUpAll(() async {
    if (pictures.isEmpty) return;
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final file in files) {
        final bytes = File('../packages/sm_design/fonts/$file')
            .readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }

    await load('packages/sm_design/IBMPlexMono', [
      'IBMPlexMono-Regular.ttf',
      'IBMPlexMono-Medium.ttf',
      'IBMPlexMono-Bold.ttf',
      'IBMPlexMono-Italic.ttf',
      'IBMPlexMono-BoldItalic.ttf',
    ]);
    await load('packages/sm_design/JetBrainsMono', [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Bold.ttf',
    ]);
    await load('packages/sm_design/NotoSansSymbols', [
      'NotoSansSymbols-Planets.ttf',
    ]);
    await load('packages/sm_design/NotoSansSymbols2', [
      'NotoSansSymbols2-Sun.ttf',
    ]);
    Directory(pictures).createSync(recursive: true);
  });

  final tables = BaziTables.parse(
    File('assets/bazi/hidden_stems.ziping.v1.json').readAsStringSync(),
    File('assets/bazi/relations.ziping.v1.json').readAsStringSync(),
  );

  final screens = <String, Widget Function()>{
    'day': () => MonthScreen(
      today: day,
      utcOffset: offset,
      lockedView: MonthScreenView.day,
    ),
    'month': () => MonthScreen(
      today: day,
      utcOffset: offset,
      lockedView: MonthScreenView.month,
    ),
    'year': () => MonthScreen(
      today: day,
      utcOffset: offset,
      lockedView: MonthScreenView.year,
    ),
    for (final system in ['hijri', 'chinese', 'javanese'])
      'year-$system': () => MonthScreen(
        today: day,
        utcOffset: offset,
        lockedView: MonthScreenView.year,
      ),
    'journal': () => JournalScreen(date: day, utcOffset: offset, today: day),
    'reminders': () => RemindersScreen(day: day, utcOffset: offset, today: day),
    'practice': () => const PracticeScreen(),
    'menu': () => const MenuScreen(),
    'manual': () => const ManualScreen(),
    'manual-tour': () => ManualTourScreen(
      feature: ManualFeature.journal,
      group: ManualGroup.journal,
      text: ShowcaseText.parse(
        File(ShowcaseText.asset).readAsStringSync(),
        AppLanguage.en,
      ),
      marks: jsonDecode(
        File(Manual.marksAsset).readAsStringSync(),
      ) as Map<String, dynamic>,
    ),
    'colours': () => const ColoursScreen(),
    'essay': () => const EssayScreen(),
    'journal-file': () => const JournalFileScreen(),
    'categories': () => const CategoriesScreen(),
    'categories-editing': () => const CategoriesScreen(),
    'place': () => const PlaceScreen(),
    'search': () => SearchScreen(date: day, utcOffset: offset, today: day),
    'reading': () => ReadingScreen(date: day, utcOffset: offset, today: day),
    'entry-new': () => EntryScreen(date: day, utcOffset: offset),
    'reminder-new': () => ReminderScreen(day: day),
    'sky': () => SkyScreen(date: day, utcOffset: offset),
    'planets': () => PlanetsScreen(date: day, utcOffset: offset),
    'stars': () => StarScreen(date: day, utcOffset: offset),
    'lintang': () => StarScreen(date: day, utcOffset: offset, javanese: true),
    'light': () => LightScreen(date: day, utcOffset: offset),
    'salat': () => SalatScreen(date: day, utcOffset: offset),
    'hilal': () => HilalScreen(date: day, utcOffset: offset),
    'mangsa': () => MangsaScreen(date: day),
    'bazi': () => BaziScreen(
      date: day,
      utcOffset: offset,
      minuteOfDay: 600,
      tables: tables,
    ),
  };
  // Where something is typed: these again with the keyboard up.
  const typed = {
    'entry-new',
    'reminder-new',
    'categories',
    'categories-editing',
    'search',
    'place',
  };
  // What is done on a screen before it is looked at.
  final steps = <String, Future<void> Function(WidgetTester)>{
    'categories-editing': (tester) async {
      await tester.tap(find.byKey(const ValueKey('category-ritual')));
      await tester.pumpAndSettle();
    },
  };

  Future<void> shoot(WidgetTester tester, String name) async {
    if (pictures.isEmpty) return;
    await tester.runAsync(() async {
      final element = find.byType(CalendarJournalApp).evaluate().single;
      final image = await captureImage(element);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$pictures/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final up in [false, if (typed.contains(name)) true]) {
      final label = up ? '$name-keyboard' : name;
      testWidgets('$label lies whole on a phone on its side', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = ratio;
        tester.view.padding = const FakeViewPadding(
          top: 24 * ratio,
          bottom: 16 * ratio,
        );
        tester.view.viewPadding = const FakeViewPadding(
          top: 24 * ratio,
          bottom: 16 * ratio,
        );
        if (up) {
          tester.view.viewInsets = const FakeViewPadding(
            bottom: keyboard * ratio,
          );
        }
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          CalendarJournalApp(
            controller: SystemController(
              locked: CalendarSystem.values
                  .where((system) => name.endsWith('-${system.name}'))
                  .firstOrNull,
            ),
            language: LanguageController(saved: AppLanguage.en),
            home: build(),
          ),
        );
        await tester.pumpAndSettle();
        await steps[name]?.call(tester);
        await shoot(tester, label);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
