import 'dart:convert';
import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/house.dart';
import 'package:candra/journal/showcase_text.dart';
import 'package:candra/menu/manual_screen.dart';
import 'package:candra/menu/policy_screen.dart';
import 'package:candra/practice/practice_screen.dart';
import 'package:candra/appearance.dart';
import 'package:candra/calendar_system.dart';
import 'package:candra/colour_schemes.dart';
import 'package:candra/menu/colours_screen.dart';
import 'package:candra/main.dart';
import 'package:candra/menu/menu_screen.dart';
import 'package:candra/menu/notes_text.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/strings.dart';
import 'package:candra/sigil.dart';
import 'package:candra/system_palettes.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));

  // What the phone was asked to open.
  final opened = <String>[];

  setUp(() {
    opened.clear();
    Manual.offered.value = false;
    Manual.preload(File(ShowcaseText.asset).readAsStringSync());
    Manual.preloadMarks(File(Manual.marksAsset).readAsStringSync());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('candra/app'), (
          call,
        ) async {
          if (call.method == 'version') return '1.0.0+3';
          if (call.method == 'open') {
            opened.add((call.arguments as Map)['url'] as String);
            return true;
          }
          return null;
        });
  });

  Future<void> pump(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
    CalendarSystem system = CalendarSystem.weton,
    Size size = const Size(1440, 3040),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController()..value = system,
        language: LanguageController(saved: language),
        home: MonthScreen(
          today: CivilDate(2026, 10, 11),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String name) async {
    await tester.ensureVisible(key(name));
    await tester.pumpAndSettle();
    await tester.tap(key(name));
    await tester.pumpAndSettle();
  }

  test('the colour choice is kept as words and read back, the unknown '
      'left as it was', () {
    addTearDown(ColourChoice.restore);
    ColourChoice.choose(CalendarSystem.chinese, ColourScheme.plum);
    ColourChoice.choose(CalendarSystem.hijri, ColourScheme.plum);
    final words = ColourChoice.encode();
    ColourChoice.restore();
    expect(ColourChoice.isDefault, isTrue);
    ColourChoice.decode(words);
    expect(ColourChoice.of(CalendarSystem.chinese), ColourScheme.plum);
    expect(ColourChoice.of(CalendarSystem.hijri), ColourScheme.plum);
    ColourChoice.decode('chinese=nothing,elsewhere=moss');
    expect(ColourChoice.isDefault, isTrue);
    // The palettes follow the choice.
    ColourChoice.choose(CalendarSystem.weton, ColourScheme.ocean);
    expect(CalendarSystem.weton.colors.accent, ColourScheme.ocean.dark.accent);
  });

  test("Gregorian is shown in the sigil's own night", () {
    expect(ColourChoice.defaults[CalendarSystem.gregorian], ColourScheme.night);
    expect(ColourScheme.night.dark.background, SigilOpening.night);
    expect(ColourScheme.night.dark.textPrimary, SigilOpening.moonlight);
  });

  testWidgets('the first time ever, the sigil traces itself over the app '
      'and then gives way to it', (tester) async {
    SigilOpening.showing.value = true;
    addTearDown(() => SigilOpening.showing.value = false);
    await pump(tester);
    expect(find.byType(SigilOpening), findsOneWidget);
    // Nothing under it is touched.
    await tester.tapAt(tester.getCenter(find.byType(MonthScreen)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SigilOpening), findsOneWidget);
    await tester.pump(
      Duration(milliseconds: (SigilTracing.length * 1000).ceil()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SigilOpening), findsNothing);
    expect(SigilOpening.showing.value, isFalse);
  });

  group('the menu', () {
    testWidgets("the app's name in the panel traces the sigil over the "
        'top bar and the rows, and any touch anywhere ends it', (tester) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      expect(key('menu-sigil'), findsNothing);
      await tester.tap(key('menu-about'));
      // The month goes round for as long as it is shown: it never settles.
      await tester.pump(const Duration(seconds: 12));
      expect(key('menu-sigil'), findsOneWidget);
      expect(key('menu-top-bar'), findsNothing);
      expect(key('menu-colours'), findsNothing);
      // A touch on the bar ends it, and only that.
      await tester.tapAt(tester.getCenter(key('part-bar')));
      await tester.pump(const Duration(seconds: 1));
      expect(key('menu-sigil'), findsNothing);
      expect(key('menu-top-bar'), findsOneWidget);
      expect(find.byType(MenuScreen), findsOneWidget);
      // So does the start of a drag on the body.
      await tester.tap(key('menu-about'));
      await tester.pump(const Duration(seconds: 2));
      await tester.dragFrom(
        tester.getCenter(key('part-body')),
        const Offset(0, -200),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(key('menu-sigil'), findsNothing);
    });

    testWidgets('colours: a calendar and a scheme from the panel, the whole '
        'screen in it, and every calendar back to its own once asked', (
      tester,
    ) async {
      addTearDown(ColourChoice.restore);
      await pump(tester);
      await tap(tester, 'menu-button');
      // At the top of the menu.
      expect(
        tester.getRect(key('menu-colours')).top,
        lessThan(tester.getRect(key('menu-data')).top),
      );
      await tap(tester, 'menu-colours');
      expect(find.byType(ColoursScreen), findsOneWidget);
      expect(key('colours-sample'), findsOneWidget);
      Color background() => SmTheme.of(
        tester.element(find.byKey(const ValueKey('colours-sample'))),
      ).colors.background;

      // Two wheels: the calendar at the left, its scheme at the right.
      // A wheel turned by [steps] rows.
      Future<void> turn(String wheel, int steps) async {
        await tester.drag(key(wheel), Offset(0, -36.0 * steps));
        await tester.pumpAndSettle();
      }

      int heading() => CalendarSystem.values.indexOf(
        CalendarSystem.values.firstWhere(
          (each) => find
              .byKey(ValueKey('colours-second-${each.index}'))
              .evaluate()
              .isNotEmpty,
        ),
      );

      // To the Chinese calendar: its own scheme, vermilion.
      await turn('colours-first', CalendarSystem.chinese.index - heading());
      expect(heading(), CalendarSystem.chinese.index);
      expect(background(), ColourScheme.vermilion.dark.background);
      // Its scheme turned to plum: the screen in plum at once.
      final chinese = 'colours-second-${CalendarSystem.chinese.index}';
      await turn(
        chinese,
        ColourScheme.plum.index - ColourScheme.vermilion.index,
      );
      expect(ColourChoice.of(CalendarSystem.chinese), ColourScheme.plum);
      expect(background(), ColourScheme.plum.dark.background);
      // The same scheme for a second calendar; the first keeps its own.
      await turn('colours-first', 1);
      final hijri = CalendarSystem.values[heading()];
      final from = ColourChoice.of(hijri);
      await turn(
        'colours-second-${hijri.index}',
        ColourScheme.plum.index - from.index,
      );
      expect(ColourChoice.of(hijri), ColourScheme.plum);
      expect(ColourChoice.of(CalendarSystem.chinese), ColourScheme.plum);

      // Restore asks; back is no.
      await tap(tester, 'colours-restore');
      expect(key('colours-restore-ask'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ColoursScreen), findsOneWidget);
      expect(ColourChoice.of(hijri), ColourScheme.plum);
      await tap(tester, 'colours-restore');
      await tester.tap(find.text('Restore defaults').last);
      await tester.pumpAndSettle();
      expect(ColourChoice.isDefault, isTrue);
      expect(background(), ColourScheme.teal.dark.background);
    });

    testWidgets('has the journal file, help and what the app is', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      expect(find.byType(MenuScreen), findsOneWidget);
      for (final row in [
        'data',
        'manual',
        'feedback',
        'reckoning',
        'privacy',
        'licences',
      ]) {
        expect(key('menu-$row'), findsOneWidget, reason: row);
      }
      expect(tester.widget<Text>(key('menu-version')).data, 'Version 1.0.0+3');
    });

    testWidgets('feedback writes to the address, privacy opens the policy', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tap(tester, 'menu-feedback');
      expect(opened, [
        'mailto:takaya@suryamajapahit.com?subject=Candra%201.0.0%2B3',
      ]);
      // The policy is read in the app (owner, 22 October 2026), not on a
      // page outside it.
      await tap(tester, 'menu-privacy');
      expect(find.byType(PolicyScreen), findsOneWidget);
      expect(opened, hasLength(1));
    });

    testWidgets('how the dates are reckoned: a chapter in the body with '
        'its own sources, the chapters to choose from in the lower panel, '
        'in both languages', (tester) async {
      for (final language in AppLanguage.values) {
        final strings = Strings(language);
        await pump(tester, language: language);
        await tap(tester, 'menu-button');
        await tap(tester, 'menu-reckoning');
        expect(find.byType(ReckoningScreen), findsOneWidget);
        final chapters = reckoningChapters(language);
        // Every chapter has its button, below the line.
        final line = tester.getRect(key('panel-separator'));
        for (final chapter in chapters) {
          expect(
            tester.getRect(key('reckoning-chapter-${chapter.id}')).top,
            greaterThan(line.bottom),
            reason: chapter.id,
          );
        }
        // It opens on the rule, which rests on no source.
        expect(find.text(chapters.first.paragraphs.first), findsOneWidget);
        expect(find.text(strings.reckoningNoSources), findsOneWidget);

        // Another chapter replaces it in the body, with its sources and
        // how far each is stood behind.
        final hijri = chapters.firstWhere((c) => c.id == 'hijri');
        await tap(tester, 'reckoning-chapter-hijri');
        expect(find.text(chapters.first.paragraphs.first), findsNothing);
        expect(find.text(hijri.paragraphs.first), findsOneWidget);
        expect(
          tester.getRect(find.text(hijri.paragraphs.first)).bottom,
          lessThan(line.top),
        );
        await tester.scrollUntilVisible(
          find.text(hijri.sources.last.cite),
          200,
          scrollable: find
              .descendant(
                of: key('reckoning-body-hijri'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.text('Control: the results were checked against it'),
          findsOneWidget,
        );

        // Back (the phone's: there is no back button) is back to the
        // menu.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MenuScreen), findsOneWidget);
        expect(key('reckoning-chapter-hijri'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    test('for now the Indonesian reads the English (owner, 23 October '
        '2026), and every chapter but the rule has its sources', () {
      final en = reckoningChapters(AppLanguage.en);
      final id = reckoningChapters(AppLanguage.id);
      expect(id.length, en.length);
      for (var i = 0; i < en.length; i++) {
        expect(id[i].name, en[i].name);
        expect(id[i].paragraphs, en[i].paragraphs);
        expect(en[i].sources.isEmpty, en[i].id == 'rule', reason: en[i].id);
      }
    });

    test('the chapters are told as by someone else: no "we", "us" or '
        '"our" (owner, 23 October 2026)', () {
      // The pronouns as they are written; not "US", as in the US Naval
      // Observatory.
      final first = RegExp(r'\b(we|We|us|our|Our|ours|ourselves)\b');
      for (final chapter in reckoningChapters(AppLanguage.en)) {
        for (final paragraph in chapter.paragraphs) {
          expect(first.hasMatch(paragraph), isFalse, reason: paragraph);
        }
      }
      expect(
        first.hasMatch(Strings(AppLanguage.en).reckoningNoSources),
        isFalse,
      );
    });

    test('a source is primary, secondary through the work it is known by, '
        'or a control', () {
      final strings = Strings(AppLanguage.en);
      // Known second-hand, but by what is not recorded.
      const untraced = {'袁樹珊 and 韋千里, on the hour of the rat.'};
      for (final chapter in reckoningChapters(AppLanguage.en)) {
        for (final source in chapter.sources) {
          final label = strings.sourceStanding(source);
          switch (source.standing) {
            case SourceStanding.read:
              expect(label, 'Primary source');
              expect(source.via, isNull);
            case SourceStanding.cited:
              if (untraced.contains(source.cite) ||
                  source.cite.contains('NPF rule')) {
                expect(label, 'Secondary source');
              } else {
                expect(source.via, isNotNull, reason: source.cite);
                expect(label, 'Secondary source, through ${source.via}');
              }
            case SourceStanding.compared:
              expect(label, 'Control: the results were checked against it');
          }
        }
      }
    });

    testWidgets('the journal file is left by going back, to the menu; the '
        'menu button there goes back to the menu too', (tester) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tap(tester, 'menu-data');
      expect(key('journal-manifest'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(key('journal-manifest'), findsNothing);
      // The room's own button, inside it, goes back to the room itself.
      await tap(tester, 'menu-data');
      expect(key('journal-manifest'), findsOneWidget);
      await tap(tester, 'menu-button');
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(key('journal-manifest'), findsNothing);
    });

    testWidgets('the licences list the typeface among the packages, and '
        'open', (tester) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tester.ensureVisible(key('menu-licences'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(key('menu-licences'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.byType(LicencesScreen), findsOneWidget);
      expect(key('licence-IBM Plex Mono'), findsOneWidget);
      expect(key('licence-JetBrains Mono'), findsOneWidget);
      await tap(tester, 'licence-IBM Plex Mono');
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(find.textContaining('SIL Open Font License'), findsWidgets);
    });

    testWidgets('dark or light at the top left of the panel: the phone\'s '
        'side until chosen, and choosing the phone\'s side follows it '
        'again', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final appearance = AppearanceController();
      tester.view.physicalSize = const Size(1440, 3040);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController()..value = CalendarSystem.weton,
          language: LanguageController(saved: AppLanguage.en),
          appearance: appearance,
          home: MonthScreen(
            today: CivilDate(2026, 10, 11),
            utcOffset: const Duration(hours: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'menu-button');
      final toggle = tester.getRect(key('appearance-toggle'));
      final panel = tester.getRect(key('panel-separator'));
      expect(toggle.left, lessThan(30));
      expect(toggle.top, lessThan(panel.bottom + 30));
      expect(find.text('What has no button of its own'), findsNothing);
      Color background() =>
          SmTheme.of(tester.element(find.byType(MenuScreen))).colors.background;
      expect(background().computeLuminance(), lessThan(0.1));

      // A touch on either half switches: here the dark half, already lit.
      await tap(tester, 'appearance-dark');
      expect(appearance.chosen, Brightness.light);
      expect(background().computeLuminance(), greaterThan(0.7));
      await tap(tester, 'appearance-dark');
      // The phone is dark: back to following it.
      expect(appearance.chosen, isNull);
      expect(background().computeLuminance(), lessThan(0.1));
      // The phone turns light, and the app with it.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(background().computeLuminance(), greaterThan(0.7));
    });

    testWidgets('fits on its side', (tester) async {
      await pump(tester, size: const Size(3040, 1440));
      await tap(tester, 'menu-button');
      expect(tester.takeException(), isNull);
      await tap(tester, 'menu-reckoning');
      expect(tester.takeException(), isNull);
    });
  });

  group('the manual', () {
    // The manual's words, as the file has them.
    final words =
        (jsonDecode(File(ShowcaseText.asset).readAsStringSync())
                as Map<String, dynamic>)
            .keys
            .where((key) => key.startsWith('manual.'))
            .toList();

    test('every feature has its card, what it is and a use; every button '
        'it names is drawn with a glyph the app has', () {
      for (final feature in ManualFeature.values) {
        for (final part in ['name', 'line', 'what', 'use.1']) {
          expect(
            words,
            contains('manual.${feature.name}.$part'),
            reason: '${feature.name} $part',
          );
        }
      }
      final glyphs = {for (final glyph in Glyph.values) glyph.name};
      for (final key in words.where((key) => key.contains('.button.'))) {
        final name = key.split('.').last;
        expect(
          glyphs.contains(name) || name == 'system' || name == 'monthButton',
          isTrue,
          reason: key,
        );
      }
      // No feature in the file that the manual does not show.
      final features = {for (final f in ManualFeature.values) f.name};
      for (final key in words) {
        final feature = key.split('.')[1];
        if (key.split('.').length > 2) {
          expect(
            features.contains(feature) ||
                feature.startsWith('page') ||
                feature == 'group',
            isTrue,
            reason: key,
          );
        }
      }
    });

    test('every feature is in one wing, and every wing has its words', () {
      final shown = [for (final g in ManualGroup.values) ...g.features];
      expect(shown.toSet(), ManualFeature.values.toSet());
      expect(shown, hasLength(ManualFeature.values.length));
      for (final group in ManualGroup.values) {
        expect(words, contains('manual.group.${group.name}.name'));
        expect(words, contains('manual.group.${group.name}.line'));
      }
    });

    testWidgets('opens from the menu: the wings as cards in the panel, the '
        'chosen one\'s exhibits as rows in the body', (tester) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tap(tester, 'menu-manual');
      expect(find.byType(ManualScreen), findsOneWidget);
      expect(key('manual-strip'), findsOneWidget);
      for (final feature in ManualGroup.menu.features) {
        expect(key('manual-row-${feature.name}'), findsOneWidget);
      }
      // The rows are in the body, over the panel's line.
      expect(
        tester.getRect(key('manual-row-menu')).bottom,
        lessThan(tester.getRect(key('panel-separator')).top),
      );
      // Another wing, its own rows.
      await tap(tester, 'manual-group-calendar');
      expect(key('manual-row-calendar'), findsOneWidget);
      expect(key('manual-row-menu'), findsNothing);
    });

    testWidgets('a row opens its exhibit over the whole page, swiped through '
        'its own pages; back returns to the wing', (tester) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tap(tester, 'menu-manual');
      await tap(tester, 'manual-row-colours');
      expect(find.byType(ManualTourScreen), findsOneWidget);
      expect(key('manual-card-colours'), findsOneWidget);
      // Over the panel's room too: the card reaches the bar.
      expect(key('panel-separator'), findsNothing);
      expect(find.textContaining('WHAT IT IS'), findsOneWidget);
      // Where the page is at the bottom left, the offer at the bottom
      // right.
      final card = tester.getRect(key('manual-card'));
      final there = tester.getRect(key('manual-take-there'));
      expect(there.right, closeTo(card.right, 40));
      expect(there.bottom, closeTo(card.bottom, 40));

      await tester.drag(key('manual-pages'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('ITS BUTTONS'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.drag(key('manual-pages'), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }
      expect(key('manual-card-colours'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ManualTourScreen), findsNothing);
      expect(key('manual-row-colours'), findsOneWidget);
    });

    testWidgets('on its side the words stand on the right and the picture '
        'on the left; turning keeps the page, its markers and all', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tap(tester, 'menu-manual');
      await tap(tester, 'manual-row-menu');
      await tester.drag(key('manual-pages'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(key('manual-marker-1'), findsOneWidget);

      tester.view.physicalSize = const Size(3040, 1440);
      await tester.pumpAndSettle();
      expect(find.textContaining('ITS BUTTONS'), findsOneWidget);
      expect(key('manual-marker-1'), findsOneWidget);
      final picture = tester.getRect(key('manual-exhibit'));
      final words = tester.getRect(key('manual-placard-title'));
      expect(words.left, greaterThan(picture.right));
      // The dots and the offer stay on the left, under the picture.
      expect(
        tester.getRect(key('manual-take-there')).right,
        lessThan(words.left),
      );
    });

    testWidgets('a flick carries the wings on, and they come to rest on one', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tap(tester, 'menu-manual');
      await tester.fling(key('manual-strip'), const Offset(-300, 0), 3000);
      await tester.pumpAndSettle();
      final strip = tester.widget<PageView>(key('manual-strip'));
      final page = strip.controller!.page!;
      expect(page, greaterThan(1));
      expect(page, closeTo(page.roundToDouble(), 0.01));
      expect(
        key(
          'manual-row-${ManualGroup.values[page.round()].features.first.name}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers to take you to a feature, and goes only when asked', (
      tester,
    ) async {
      await pump(tester);
      await tap(tester, 'menu-button');
      await tap(tester, 'menu-manual');
      tester
          .widget<PageView>(key('manual-strip'))
          .controller!
          .jumpToPage(ManualGroup.practice.index);
      await tester.pumpAndSettle();
      await tap(tester, 'manual-row-practice');
      expect(find.byType(PracticeScreen), findsNothing);
      await tap(tester, 'manual-take-there');
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(
        House.maybeOf(
          tester.element(find.byType(MonthScreen, skipOffstage: false)),
        )!.room.value,
        Room.practice,
      );
    });

    testWidgets('someone new is told once where the manual is, over the '
        'lower panel, and left to it', (tester) async {
      Manual.offered.value = true;
      await pump(tester);
      await tester.pumpAndSettle();
      expect(key('manual-offer'), findsOneWidget);
      expect(find.textContaining('The manual is in the menu'), findsOneWidget);
      final offer = tester.getRect(key('manual-offer'));
      expect(
        offer.top,
        greaterThan(tester.getRect(key('panel-separator')).top),
      );
      await tap(tester, 'manual-offer-ok');
      expect(key('manual-offer'), findsNothing);
      expect(Manual.offered.value, isFalse);
      // Nothing was opened for them.
      expect(find.byType(ManualScreen), findsNothing);
    });
  });
}
