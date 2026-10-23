import 'dart:async';
import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/geo.dart';
import 'package:candra/journal/journal_screen.dart';
import 'package:candra/journal/journal_storage.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/strings.dart';
import 'package:candra/toast.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// Stands in for the phone: says where it is, and remembers what it was
/// asked to open.
class FakeLocator extends Locator {
  FakeLocator({this.fix, this.problem, this.hasMaps = true, this.slow = false});

  /// Whether a search goes on until it is stopped.
  final bool slow;
  Completer<Fix>? _looking;
  var cancelled = 0;

  final Fix? fix;
  final LocateProblem? problem;
  final bool hasMaps;
  var asked = 0;
  final opened = <GeoTag>[];

  @override
  Future<Fix> find() async {
    asked++;
    if (slow) return (_looking = Completer<Fix>()).future;
    if (problem != null) throw LocateFailed(problem!);
    return fix!;
  }

  @override
  Future<void> cancel() async {
    cancelled++;
    _looking?.completeError(const LocateFailed(LocateProblem.cancelled));
    _looking = null;
  }

  @override
  Future<bool> open(GeoTag place) async {
    opened.add(place);
    return hasMaps;
  }
}

void main() {
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 11);
  // Borobudur, to more places than are kept.
  const borobudur = (
    latitude: -7.607874,
    longitude: 110.203751,
    accuracy: 12.0,
  );
  // As long as a name is ever likely to be, and then some.
  const longName =
      'Pesanggrahan Agung Ambarrukmo Palace Pendopo Sisi Timur dekat Gerbang '
      'Utama yang Menghadap ke Arah Gunung Merapi';

  Entry entry({GeoTag? place, String title = 'Offering', int minute = 600}) =>
      Entry(
        id: '',
        date: day,
        minuteOfDay: minute,
        utcOffset: offset,
        categoryId: 'ritual',
        title: title,
        content: 'Words.',
        place: place,
      );

  group('a geotag', () {
    test('is rounded to about a hundred metres, never the exact spot', () {
      final tag = GeoTag.rounded(borobudur.latitude, borobudur.longitude)!;
      expect(tag.latitude, -7.608);
      expect(tag.longitude, 110.204);
      expect(tag.coordinates, '-7.608, 110.204');
      // What was thrown away is less than the size of one step.
      final exact = GeoTag.rounded(-7.6084, 110.2036)!;
      expect(tag.distanceTo(exact), lessThan(120));
      // The equator and the meridian are written without a stray sign.
      expect(GeoTag.rounded(-0.0001, 0.0002)!.coordinates, '0.000, 0.000');
    });

    test('is refused off the globe', () {
      expect(GeoTag.rounded(91, 0), isNull);
      expect(GeoTag.rounded(0, 181), isNull);
      expect(GeoTag.rounded(double.nan, 0), isNull);
    });

    test('has a name on one line, or its coordinates for a label', () {
      final tag = GeoTag.rounded(-7.608, 110.204)!;
      expect(tag.label, '-7.608, 110.204');
      expect(tag.named('  Candi \n Borobudur ').name, 'Candi Borobudur');
      expect(tag.named('Candi Borobudur').label, 'Candi Borobudur');
    });

    test('is written in the entry file as plain text, and read back', () {
      final tag = GeoTag.rounded(-7.608, 110.204, name: 'Candi Borobudur')!;
      final text = EntryFile.encode(entry(place: tag), categoryName: 'Ritual');
      expect(text, contains('\nlatitude: -7.608\n'));
      expect(text, contains('\nlongitude: 110.204\n'));
      expect(text, contains('\nplace: Candi Borobudur\n'));
      // The file says, in so many words, that it is not the exact spot.
      expect(text, contains('rounded to about 100 m: not the exact spot'));
      expect(EntryFile.decode(text)!.place, tag);

      // No tag, no lines.
      final plain = EntryFile.encode(entry(), categoryName: 'Ritual');
      expect(plain, isNot(contains('latitude')));
      expect(EntryFile.decode(plain)!.place, isNull);

      // A file edited by hand to hold more is rounded on the way in.
      final precise = text.replaceFirst('-7.608', '-7.60787412');
      expect(EntryFile.decode(precise)!.place!.latitude, -7.608);
      // And one with a name that has a colon in it keeps the whole name.
      final colon = EntryFile.encode(
        entry(place: tag.named('Pura: the east gate')),
        categoryName: 'Ritual',
      );
      expect(EntryFile.decode(colon)!.place!.name, 'Pura: the east gate');
    });
  });

  group('named places', () {
    late Directory root;
    late JournalStore store;

    setUp(() {
      root = Directory.systemTemp.createTempSync('geotag-test');
      store = JournalStore(FileJournalStorage.open(root));
    });
    tearDown(() {
      store.dispose();
      root.deleteSync(recursive: true);
    });

    Entry at(GeoTag? place, int minute) => Entry(
      id: '',
      date: day,
      minuteOfDay: minute,
      utcOffset: offset,
      categoryId: store.categories.first.id,
      title: 'x',
      content: '',
      place: place,
    );

    test('are the names given to geotags before, offered when near', () {
      final here = GeoTag.rounded(-7.608, 110.204)!;
      store.save(at(here.named('Candi Borobudur'), 1));
      // The same name twice is offered once.
      store.save(at(here.named('Candi Borobudur'), 2));
      // About 220 m north.
      store.save(at(GeoTag.rounded(-7.606, 110.204, name: 'North gate'), 3));
      // About 1.1 km away: not near.
      store.save(at(GeoTag.rounded(-7.618, 110.204, name: 'Mendut'), 4));
      // Tagged but never named: nothing to offer.
      store.save(at(here, 5));
      store.save(at(null, 6));

      expect(store.placesNear(here).map((p) => p.name), [
        'Candi Borobudur',
        'North gate',
      ]);
      expect(store.placesNear(GeoTag.rounded(0, 0)!), isEmpty);

      // It is all in the files: a journal opened again knows them too,
      // and so does one whose index is made afresh.
      store.dispose();
      final storage = FileJournalStorage.open(root)..rebuildIndex();
      store = JournalStore(storage);
      expect(store.placesNear(here).map((p) => p.name), [
        'Candi Borobudur',
        'North gate',
      ]);
      expect(
        store.entriesFor(day, utcOffset: offset).where((e) => e.place != null),
        hasLength(5),
      );
    });
  });

  group('on the entry screen', () {
    Finder key(String name) => find.byKey(ValueKey(name));

    late FakeLocator phone;

    Future<JournalStore> pump(
      WidgetTester tester, {
      Entry? saved,
      FakeLocator? locator,
      AppLanguage language = AppLanguage.en,
      Widget Function(Entry? saved)? home,
    }) async {
      tester.view.physicalSize = const Size(1440, 3040);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      phone = locator ?? FakeLocator(fix: borobudur);
      Locator.current = phone;
      addTearDown(() => Locator.current = const PhoneLocator());
      final store = JournalStore();
      final kept = saved == null ? null : store.save(saved);
      await tester.pumpWidget(
        CalendarJournalApp(
          controller: SystemController(),
          language: LanguageController(saved: language),
          journal: store,
          home:
              home?.call(kept) ??
              EntryScreen(
                date: day,
                utcOffset: offset,
                entry: kept,
                categoryId: 'ritual',
                minuteOfDay: 600,
              ),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    Future<void> tap(WidgetTester tester, String name) async {
      await tester.tap(key(name));
      await tester.pumpAndSettle();
    }

    Finder nameField() => find.descendant(
      of: key('place-name'),
      matching: find.byType(EditableText),
    );

    Finder titleField() => find.descendant(
      of: key('entry-title'),
      matching: find.byType(EditableText),
    );

    Future<void> letToastGo(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('the pin is at the top right of the top bar, and tags the '
        'entry with where the phone is, rounded', (tester) async {
      final store = await pump(tester);
      final pin = tester.getRect(key('entry-place'));
      final bar = tester.getRect(key('entry-top-bar'));
      expect(pin.right, closeTo(bar.right, 0.01));
      expect(pin.top, closeTo(bar.top, 4));
      expect(tester.widget<GlyphButton>(key('entry-place')).glyph, Glyph.place);
      expect(tester.widget<GlyphButton>(key('entry-place')).lit, isFalse);
      // Nothing was asked of the phone until now.
      expect(phone.asked, 0);

      await tester.tap(key('entry-place'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(phone.asked, 1);
      await tester.pumpAndSettle();

      // Tagged, and the button lit.
      expect(tester.widget<GlyphButton>(key('entry-place')).lit, isTrue);
      // The place bar and its panel are up, the panel saying, in so many
      // words and for as long as it is there, that it is not the exact
      // spot. Nothing about a geotag is said in a toast.
      expect(
        find
            .byType(Toast)
            .evaluate()
            .every((e) => (e.widget as Toast).message == null),
        isTrue,
      );
      expect(key('place-bar'), findsOneWidget);
      expect(
        tester.widget<Text>(key('place-coordinates')).data,
        '-7.608, 110.204',
      );
      expect(
        tester.widget<Text>(key('place-precision')).data,
        contains('Rounded to about 100 m'),
      );
      // Beside the time, in the top bar.
      expect(
        find.descendant(
          of: key('entry-place-beside'),
          matching: find.textContaining('-7.608, 110.204'),
        ),
        findsOneWidget,
      );
      final time = tester.getRect(find.textContaining('· 10:00'));
      final beside = tester.getRect(key('entry-place-beside'));
      expect(beside.left, greaterThanOrEqualTo(time.right - 0.01));
      expect(beside.center.dy, closeTo(time.center.dy, 2));
      await letToastGo(tester);

      // Named, and saved with the entry.
      await tester.enterText(nameField(), 'Candi Borobudur');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: key('entry-place-beside'),
          matching: find.textContaining('Candi Borobudur'),
        ),
        findsOneWidget,
      );
      await tap(tester, 'place-done');
      expect(key('place-bar'), findsNothing);
      await tester.enterText(titleField(), 'At the temple');
      await tester.pumpAndSettle();
      await tap(tester, 'entry-save');

      final saved = store
          .entriesFor(day, utcOffset: offset)
          .firstWhere((e) => e.title == 'At the temple');
      expect(
        saved.place,
        GeoTag.rounded(-7.608, 110.204, name: 'Candi Borobudur'),
      );

      // Reading it: no top bar, and the place under the time.
      expect(key('entry-place'), findsNothing);
      final when = tester.getRect(find.textContaining('· 10:00'));
      final under = tester.getRect(key('entry-place-under'));
      expect(under.top, greaterThanOrEqualTo(when.bottom));
      expect(
        find.descendant(
          of: key('entry-place-under'),
          matching: find.text('Candi Borobudur'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('entry-place-under'),
          matching: find.text('-7.608, 110.204'),
        ),
        findsOneWidget,
      );
      // A tap hands it to the phone's maps app.
      await tap(tester, 'entry-place-under');
      expect(phone.opened.single, saved.place);
    });

    testWidgets('one geotag an entry: the pin opens the place bar on a '
        'tagged entry, and the bin takes the tag off', (tester) async {
      final tag = GeoTag.rounded(-7.608, 110.204, name: 'Candi Borobudur')!;
      final store = await pump(tester, saved: entry(place: tag));
      await tap(tester, 'entry-edit');
      expect(tester.widget<GlyphButton>(key('entry-place')).lit, isTrue);

      // Pressed on a tagged entry it does not look again.
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      expect(phone.asked, 0);
      expect(key('place-bar'), findsOneWidget);
      expect(
        tester.widget<EditableText>(nameField()).controller.text,
        'Candi Borobudur',
      );
      // And closes it again.
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      expect(key('place-bar'), findsNothing);

      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      await tap(tester, 'place-remove');
      expect(key('place-bar'), findsNothing);
      expect(key('entry-place-beside'), findsNothing);
      expect(tester.widget<GlyphButton>(key('entry-place')).lit, isFalse);
      await tap(tester, 'entry-done');
      expect(store.entriesFor(day, utcOffset: offset).last.place, isNull);
      expect(key('entry-place-under'), findsNothing);
    });

    testWidgets('leaving the editor without saving leaves the tag as it was', (
      tester,
    ) async {
      final store = await pump(tester, saved: entry());
      await tap(tester, 'entry-edit');
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      await tap(tester, 'place-done');
      await letToastGo(tester);
      // Back, while editing, stops editing without saving.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('entry-edit'), findsOneWidget);
      expect(store.entriesFor(day, utcOffset: offset).last.place, isNull);
      expect(key('entry-place-under'), findsNothing);
    });

    testWidgets('names given near here before are offered, and one tap '
        'takes one', (tester) async {
      final store = await pump(
        tester,
        saved: entry(
          place: GeoTag.rounded(-7.607, 110.204, name: 'Candi Borobudur'),
          minute: 500,
        ),
        home: (_) => EntryScreen(
          date: day,
          utcOffset: offset,
          categoryId: 'ritual',
          minuteOfDay: 600,
        ),
      );
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      expect(find.text('NEARBY'), findsOneWidget);
      await tap(tester, 'nearby-Candi Borobudur');
      expect(
        tester.widget<EditableText>(nameField()).controller.text,
        'Candi Borobudur',
      );
      await tap(tester, 'place-done');
      await letToastGo(tester);
      await tester.enterText(titleField(), 'Again');
      await tester.pumpAndSettle();
      await tap(tester, 'entry-save');
      expect(
        store
            .entriesFor(day, utcOffset: offset)
            .firstWhere((e) => e.title == 'Again')
            .place!
            .name,
        'Candi Borobudur',
      );
    });

    testWidgets('says why when the phone cannot say where it is, and tags '
        'nothing', (tester) async {
      for (final (problem, words) in [
        (LocateProblem.denied, 'not allowed to use location'),
        (LocateProblem.off, 'Location is switched off'),
        (LocateProblem.timeout, 'Try again outdoors or by a window'),
        (LocateProblem.sky, 'using GPS only'),
        (LocateProblem.unavailable, 'cannot say where it is'),
      ]) {
        await pump(tester, locator: FakeLocator(problem: problem));
        await tester.tap(key('entry-place'));
        await tester.pumpAndSettle();
        // Said in the place panel, where it stays.
        expect(
          find.descendant(
            of: key('place-panel'),
            matching: find.textContaining(words),
          ),
          findsOneWidget,
        );
        expect(tester.widget<GlyphButton>(key('entry-place')).lit, isFalse);
        expect(key('place-bar'), findsNothing);
        await tester.pump(const Duration(seconds: 30));
        expect(key('place-notice'), findsOneWidget);
        // A tap on it puts it away.
        await tester.tap(key('place-notice'));
        await tester.pumpAndSettle();
        expect(key('place-panel'), findsNothing);
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a search that goes on says so, and the pin or the back '
        'button stops it', (tester) async {
      await pump(tester, locator: FakeLocator(slow: true));
      await tester.tap(key('entry-place'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.descendant(
          of: key('place-panel'),
          matching: find.textContaining('Tap the pin again to stop'),
        ),
        findsOneWidget,
      );
      // The pin shows it is busy.
      expect(tester.widget<GlyphButton>(key('entry-place')).marked, isTrue);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Still looking'), findsOneWidget);

      // The pin again: stopped, with nothing tagged and nothing said.
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      expect(phone.cancelled, 1);
      expect(find.textContaining('Still looking'), findsNothing);
      expect(tester.widget<GlyphButton>(key('entry-place')).marked, isFalse);
      expect(tester.widget<GlyphButton>(key('entry-place')).lit, isFalse);
      expect(key('place-bar'), findsNothing);

      // Back stops a search too, before it leaves the entry.
      await tester.tap(key('entry-place'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(phone.cancelled, 2);
      expect(find.byType(EntryScreen), findsOneWidget);
    });

    testWidgets('back closes the place bar before it leaves the entry', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      expect(key('place-bar'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('place-bar'), findsNothing);
      expect(find.byType(EntryScreen), findsOneWidget);
      // The tag itself stays.
      expect(tester.widget<GlyphButton>(key('entry-place')).lit, isTrue);
      await letToastGo(tester);
    });

    testWidgets('says so when the phone only gave an approximate position', (
      tester,
    ) async {
      await pump(
        tester,
        locator: FakeLocator(
          fix: (latitude: -7.6, longitude: 110.2, accuracy: 2000.0),
        ),
      );
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: key('place-panel'),
          matching: find.textContaining('off by about 2 km'),
        ),
        findsOneWidget,
      );
      // With the coordinates and the note that they are rounded.
      expect(key('place-coordinates'), findsOneWidget);
      expect(key('place-precision'), findsOneWidget);
      await letToastGo(tester);
    });

    testWidgets('says so when there is no maps app', (tester) async {
      await pump(
        tester,
        saved: entry(place: GeoTag.rounded(-7.608, 110.204)),
        locator: FakeLocator(hasMaps: false),
      );
      // With no name, the coordinates alone.
      expect(
        find.descendant(
          of: key('entry-place-under'),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      await tap(tester, 'entry-place-under');
      expect(find.text('No maps app on this phone.'), findsOneWidget);
      await letToastGo(tester);
    });

    testWidgets('a very long name is cut where there is no room, and never '
        'pushes anything off the screen', (tester) async {
      final tag = GeoTag.rounded(-7.608, 110.204, name: longName)!;
      await pump(
        tester,
        saved: entry(
          place: tag,
          title: 'A title that is itself rather long for one line of a card',
        ),
      );
      final screen = tester.getRect(find.byType(EntryScreen));

      // Reading: under the time, the name on two lines at most, the
      // coordinates still there below it.
      final under = tester.getRect(key('entry-place-under'));
      expect(under.right, lessThanOrEqualTo(screen.right));
      final name = tester.widget<Text>(find.text(longName));
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(find.text('-7.608, 110.204'), findsOneWidget);
      expect(
        tester.getSize(find.text(longName)).height,
        lessThan(tester.getSize(find.text('-7.608, 110.204')).height * 2.5),
      );

      // Editing: beside the time, all on the one line; the time is whole.
      await tap(tester, 'entry-edit');
      final bar = tester.getRect(key('entry-top-bar'));
      final beside = tester.getRect(key('entry-place-beside'));
      final time = tester.getRect(find.textContaining('· 10:00'));
      expect(beside.right, lessThanOrEqualTo(bar.right + 0.01));
      expect(beside.height, lessThan(time.height * 1.5));
      expect(time.left, closeTo(bar.left, 0.01));
      // The coordinates are the last thing on the line, and the name is
      // what gives way.
      final shown = tester.widgetList<Text>(
        find.descendant(
          of: key('entry-place-beside'),
          matching: find.byType(Text),
        ),
      );
      expect(shown.first.data, ' · $longName');
      expect(shown.first.overflow, TextOverflow.ellipsis);
      expect(shown.last.data, ' · -7.608, 110.204');
      expect(
        tester.getRect(find.text(' · -7.608, 110.204')).right,
        closeTo(bar.right, 0.01),
      );
      // The top bar is the size it is with no tag at all.
      final tagged = bar.height;
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      // The place bar holds it too, in a field that scrolls.
      expect(
        tester.getRect(key('place-bar')).right,
        lessThanOrEqualTo(screen.right),
      );
      await tap(tester, 'place-remove');
      expect(tester.getRect(key('entry-top-bar')).height, tagged);
    });

    testWidgets('the journal\'s tile carries the place on one quiet line', (
      tester,
    ) async {
      late Entry long;
      late Entry plain;
      final store = await pump(
        tester,
        saved: entry(
          place: GeoTag.rounded(-7.608, 110.204, name: longName),
          title: 'A title that is itself rather long for one line of a card',
          minute: 601,
        ),
        home: (saved) {
          long = saved!;
          return JournalScreen(date: day, utcOffset: offset, today: day);
        },
      );
      plain = store.save(
        entry(place: GeoTag.rounded(-7.608, 110.204), minute: 602),
      );
      final untagged = store.save(entry(minute: 603));
      await tester.pumpAndSettle();

      // Named: the name alone, on one line, inside the tile.
      final line = key('place-${long.id}');
      final tile = tester.getRect(key('entry-${long.id}'));
      expect(tester.getRect(line).right, lessThan(tile.right));
      final words = tester.widget<Text>(
        find.descendant(of: line, matching: find.byType(Text)),
      );
      expect(words.data, longName);
      expect(words.maxLines, 1);
      expect(words.overflow, TextOverflow.ellipsis);
      expect(
        find.descendant(of: line, matching: find.textContaining('110.204')),
        findsNothing,
      );
      // Not named: the coordinates.
      expect(
        find.descendant(
          of: key('place-${plain.id}'),
          matching: find.text('-7.608, 110.204'),
        ),
        findsOneWidget,
      );
      // Not tagged: nothing, and the tile is that much shorter.
      expect(key('place-${untagged.id}'), findsNothing);
      expect(
        tester.getSize(key('entry-${untagged.id}')).height,
        lessThan(tester.getSize(key('entry-${plain.id}')).height),
      );
    });

    testWidgets('speaks Indonesian too', (tester) async {
      await pump(tester, language: AppLanguage.id);
      await tester.tap(key('entry-place'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sekitar 100 m'), findsOneWidget);
      expect(find.text('Nama tempat ini'), findsOneWidget);
      await letToastGo(tester);
    });
  });
}
