import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:candra/app_shell.dart';
import 'package:candra/bar_button.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/iching/iching_cast_screen.dart';
import 'package:candra/iching/iching_library.dart';
import 'package:candra/iching/iching_pack.dart';
import 'package:candra/iching/iching_reading_screen.dart';
import 'package:candra/iching/iching_record.dart';
import 'package:candra/iching/iching_screen.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/parts.dart';
import 'package:candra/strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

/// Chance that falls as it is told to.
class _Scripted implements Random {
  final List<bool> coins;
  int _next = 0;

  _Scripted(this.coins);

  @override
  bool nextBool() => coins[_next++ % coins.length];

  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;
}

void main() {
  Finder key(String name) => find.byKey(ValueKey(name));

  // The pack as the app ships it.
  final pack = IchingPack.parse(
    File('assets/iching/pack.v2.json').readAsStringSync(),
  );
  // What the entry's card and the pages opened from it read.
  setUp(() {
    IchingPack.use(pack);
    // The tests read our notes too; the public does not (IchingDrafts).
    IchingDrafts.shown.value = true;
  });
  tearDown(() => IchingDrafts.shown.value = false);

  const offset = Duration(hours: 7);

  Future<void> pump(
    WidgetTester tester, {
    List<bool> coins = const [true, false, false],
    AppLanguage language = AppLanguage.en,
    Size size = const Size(1440, 3040),
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: language),
        home: home ?? IchingScreen(pack: pack, random: _Scripted(coins)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String name) async {
    await tester.ensureVisible(key(name));
    await tester.pumpAndSettle();
    await tester.tap(key(name));
    await tester.pumpAndSettle();
  }

  Future<void> castSix(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tap(tester, 'iching-cast');
    }
  }

  String text(WidgetTester tester, String name) =>
      tester.widget<Text>(key(name)).data!;

  // The subtitle of the top bar with [bar]'s key.
  String subtitle(WidgetTester tester, String bar) => tester
      .widgetList<Text>(
        find.descendant(of: key(bar), matching: find.byType(Text)),
      )
      .last
      .data!;

  // Swipes the reading card's pages [times] on (or back, if negative).
  Future<void> swipe(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times.abs(); i++) {
      await tester.drag(
        key('iching-reading-pages'),
        Offset(times > 0 ? -400 : 400, 0),
      );
      await tester.pumpAndSettle();
    }
  }

  // The label of the button that turns the card to the other hexagram.
  String turn(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(of: key('iching-switch'), matching: find.byType(Text)),
      )
      .data!;

  JournalStore journalOf(WidgetTester tester) =>
      tester.widget<JournalScope>(find.byType(JournalScope)).notifier!;

  // Whether the card [id] can be touched (an ActionCard not enabled is
  // under an IgnorePointer that ignores).
  bool enabled(WidgetTester tester, String id) => !tester
      .widget<IgnorePointer>(
        find.ancestor(of: key(id), matching: find.byType(IgnorePointer)).first,
      )
      .ignoring;

  group('the pack', () {
    test('is version 2, has the sixty-four, each figure once, and finds one '
        'by its lines or its trigrams', () {
      expect(pack.hexagrams.length, 64);
      expect({for (final h in pack.hexagrams) h.figure.join()}.length, 64);
      expect(pack.of(List.filled(6, true)).name, '乾');
      expect(pack.of(List.filled(6, false)).name, '坤');
      expect(pack.of([true, false, true, false, true, false]).name, '既濟');
      expect(pack.made(Trigram.zhen, Trigram.kan).number, 3);
      expect(pack.made(Trigram.zhen, Trigram.kan).name, '屯');
      for (final h in pack.hexagrams) {
        expect(pack.made(h.lowerTrigram, h.upperTrigram).number, h.number);
        expect(h.lines.length, h.number < 3 ? 7 : 6);
      }
      expect(pack.licence, 'CC BY-SA 4.0');
      // 9, 8, 8, 7, 8, 8 from the bottom is 震 doubled, 51, its first line
      // changing to make 16 豫 (and not 3 屯, whose fourth line is yin).
      final thunder = YijingCast([
        for (final n in [9, 8, 8, 7, 8, 8]) LineValue.of(n),
      ]);
      expect(pack.of(thunder.primary).number, 51);
      expect(pack.of(thunder.relating).number, 16);
      expect(
        () => IchingPack.parse('{"version": 1}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('the name\'s pinyin has its tones where they are written, and '
        'the plain pinyin where not yet', () {
      for (final h in pack.hexagrams) {
        expect(h.spoken, h.sound?.name ?? h.pinyin);
        if (h.sound case final sound?) {
          expect(sound.lines.length, anyOf(0, h.lines.length));
        }
      }
      final bare = IchingPack.parse(
        File('assets/iching/pack.v2.json')
            .readAsStringSync()
            .replaceAll('"pinyinTones"', '"pinyinUnused"'),
      );
      expect(bare.hexagrams.first.sound, isNull);
      expect(bare.hexagrams.first.spoken, 'Qian');
    });

    test('Indonesian reads the English where it has none, and says so', () {
      final qian = pack.hexagrams.first;
      final english = qian.readIn(AppLanguage.en)!;
      expect(english.borrowed, isFalse);
      expect(english.reading.lines.length, 7);
      if (qian.reading(AppLanguage.id) == null) {
        final read = qian.readIn(AppLanguage.id)!;
        expect(read.borrowed, isTrue);
        expect(read.reading.name, english.reading.name);
      }
      for (final h in pack.hexagrams) {
        if (h.reading(AppLanguage.en) == null) {
          expect(h.readIn(AppLanguage.id), isNull);
        }
      }
    });
  });

  group('the record', () {
    final record = IchingRecord(
      method: CastMethod.stalks,
      lines: [
        for (final n in [7, 8, 9, 6, 7, 8]) LineValue.of(n),
      ],
      date: CivilDate(2026, 10, 24),
      minute: 19 * 60 + 5,
      offset: offset,
    );

    test('goes to its line and back, and refuses what cannot be', () {
      expect(
        record.value,
        'v1 method=stalks lines=789678 date=2026-10-24 time=19:05 '
        'offset=+07:00',
      );
      final back = IchingRecord.parse(record.value)!;
      expect(back.value, record.value);
      expect(back.method, CastMethod.stalks);
      expect(back.cast.changing, [2, 3]);
      expect(back.minute, 19 * 60 + 5);
      expect(back.offset, offset);
      for (final broken in [
        record.value.replaceFirst('lines=789678', 'lines=78967'),
        record.value.replaceFirst('lines=789678', 'lines=789675'),
        record.value.replaceFirst('method=stalks', 'method=dice'),
        record.value.replaceFirst('2026-10-24', '2026-02-31'),
        record.value.replaceFirst('19:05', '25:05'),
        record.value.replaceFirst('+07:00', '+15:00'),
        record.value.replaceFirst(' time=19:05', ''),
        'v2 ${record.value.substring(3)}',
      ]) {
        expect(IchingRecord.parse(broken), isNull, reason: broken);
      }
      expect(IchingRecord.parse(null), isNull);
      final byHand = record.value.replaceFirst('stalks', 'manual');
      expect(IchingRecord.parse(byHand)!.method, CastMethod.manual);
      expect(IchingRecord.parse(byHand)!.value, byHand);
    });

    test('a cast\'s entry keeps it in its file, as one iching: line, out of '
        'its text', () {
      final entry = Entry(
        id: '',
        date: CivilDate(2026, 10, 24),
        minuteOfDay: 19 * 60 + 5,
        utcOffset: offset,
        categoryId: 'ritual',
        title: '3 屯 → 8 比',
        content: 'Whether to move.',
        iching: record.value,
      );
      final file = EntryFile.encode(entry, categoryName: 'Occasion');
      expect(file, contains('\niching: ${record.value}\n'));
      final back = EntryFile.decode(file)!;
      expect(back.iching, record.value);
      expect(back.bazi, isNull);
      expect(back.content, 'Whether to move.');
      expect(back.sameAs(entry.at(entry.secondOfDay)), isTrue);
      expect(back.sameAs(entry.copyWith(iching: 'v1 other')), isFalse);
    });
  });

  testWidgets('the I Ching page is a quiet body and four cards, the three '
      'ways of casting and, set apart, the book', (tester) async {
    await pump(tester);
    expect(key('iching-yi'), findsOneWidget);
    final stalks = tester.getRect(key('iching-stalks'));
    final coins = tester.getRect(key('iching-coins'));
    final manual = tester.getRect(key('iching-manual'));
    final read = tester.getRect(key('iching-read'));
    // Left to right: Stalks, Coins, Manual, Read.
    expect(stalks.left, lessThan(coins.left));
    expect(coins.left, lessThan(manual.left));
    expect(manual.left, lessThan(read.left));
    // Read stands further off than the casting cards stand from each
    // other, and on a ground of its own with no outline.
    expect(read.left - manual.right, greaterThan(coins.left - stalks.right));
    BoxDecoration ground(String id) =>
        tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: key(id),
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(ground('iching-read').color, isNot(ground('iching-coins').color));
    expect((ground('iching-read').border! as Border).top.color.a, 0);
    expect((ground('iching-coins').border! as Border).top.color.a, 1);

    await tap(tester, 'iching-coins');
    expect(find.byType(IchingCastScreen), findsOneWidget);
    expect(find.text('Coins'), findsWidgets);
    expect(subtitle(tester, 'iching-cast-top-bar'), 'Line 1 of 6');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tap(tester, 'iching-stalks');
    expect(find.text('Stalks'), findsWidgets);
    expect(find.textContaining('Forty-nine stalks'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tap(tester, 'iching-manual');
    expect(find.text('Manual'), findsWidgets);
    expect(key('iching-manual-rows'), findsOneWidget);
    expect(key('iching-cast'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tap(tester, 'iching-read');
    expect(find.byType(IchingLibrary), findsOneWidget);
    expect(key('iching-row-1'), findsOneWidget);
  });

  testWidgets('a hold of five seconds on the faint 易 shows our notes, '
      'another hides them; a shorter hold or a wandering finger does '
      'nothing', (tester) async {
    IchingDrafts.shown.value = false;
    await pump(tester);
    final yi = tester.getCenter(key('iching-yi'));

    var finger = await tester.startGesture(yi);
    await tester.pump(const Duration(seconds: 4));
    await finger.up();
    expect(IchingDrafts.shown.value, isFalse);

    finger = await tester.startGesture(yi);
    await tester.pump(const Duration(seconds: 2));
    await finger.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(seconds: 4));
    await finger.up();
    expect(IchingDrafts.shown.value, isFalse);

    finger = await tester.startGesture(yi);
    await tester.pump(const Duration(seconds: 5));
    await finger.up();
    expect(IchingDrafts.shown.value, isTrue);
    // Nothing on screen says so.
    expect(tester.takeException(), isNull);

    finger = await tester.startGesture(yi);
    await tester.pump(const Duration(seconds: 5));
    await finger.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(IchingDrafts.shown.value, isFalse);
  });

  testWidgets('six throws of the coins build the hexagram from the bottom; '
      'then it can be read, and the cast begun again', (tester) async {
    // Two backs and a face each time: seven, a yang line at rest.
    await pump(tester);
    await tap(tester, 'iching-coins');
    expect(find.text('Hold the question, then cast.'), findsOneWidget);
    // Before it stands, nothing to save or read.
    expect(enabled(tester, 'iching-load'), isTrue);
    expect(enabled(tester, 'iching-save'), isFalse);
    expect(enabled(tester, 'iching-reading'), isFalse);
    await tap(tester, 'iching-cast');
    expect(text(tester, 'iching-value'), '7 · yang');
    expect(subtitle(tester, 'iching-cast-top-bar'), 'Line 2 of 6');
    for (var i = 0; i < 5; i++) {
      await tap(tester, 'iching-cast');
    }
    final english = pack.hexagrams.first.readIn(AppLanguage.en)!.reading.name;
    expect(subtitle(tester, 'iching-cast-top-bar'), '1 · 乾 · $english');
    expect(enabled(tester, 'iching-save'), isTrue);
    expect(enabled(tester, 'iching-reading'), isTrue);
    // The panel: load, save and the reading; no card for what it becomes.
    expect(key('iching-becomes'), findsNothing);
    expect(key('iching-cast'), findsNothing);

    // The cast stays where it was, in the middle of the body; casting
    // afresh under it at the bottom left, in the red of what destroys.
    final body = tester.getRect(find.byType(IchingCastScreen));
    final coins = tester.getRect(key('iching-throw'));
    final figure = tester.getRect(key('iching-building'));
    final again = tester.getRect(key('iching-again'));
    expect(figure.bottom, lessThan(coins.top));
    expect(coins.bottom, lessThan(again.top));
    expect(coins.center.dy, lessThan(body.center.dy));
    expect(again.right, lessThan(body.width / 4));
    expect(tester.widget<GlyphButton>(key('iching-again')).tint, dangerColor);

    // Read: no line changing, said so quietly, and nothing to turn to.
    await tap(tester, 'iching-reading');
    expect(find.byType(IchingReadingScreen), findsOneWidget);
    expect(text(tester, 'iching-name'), '乾');
    expect(key('iching-no-change'), findsOneWidget);
    expect(key('iching-line-0'), findsNothing);
    expect(key('iching-dot-5'), findsOneWidget);
    expect(key('iching-dot-6'), findsNothing);
    expect(key('iching-switch'), findsNothing);
    // No top bar and no lower panel: the card over the house's bar.
    expect(find.byType(TopBar), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tap(tester, 'iching-again');
    expect(key('iching-cast'), findsOneWidget);
    expect(subtitle(tester, 'iching-cast-top-bar'), 'Line 1 of 6');
  });

  testWidgets('a cast whose lines change is read with a button at the foot '
      'of the card that turns it to the one it becomes, and back', (
    tester,
  ) async {
    // Three backs each time: nine, a yang line that changes. All six
    // change, so Heaven becomes Earth and the seventh text is read.
    await pump(tester, coins: [true]);
    await tap(tester, 'iching-coins');
    await castSix(tester);
    expect(key('iching-becomes'), findsNothing);

    await tap(tester, 'iching-reading');
    expect(text(tester, 'iching-name'), '乾');
    expect(text(tester, 'iching-page-name'), 'MAIN');
    for (var i = 0; i < 7; i++) {
      expect(key('iching-line-$i'), findsOneWidget);
    }
    expect(key('iching-line-changes-0'), findsOneWidget);
    await tester.scrollUntilVisible(
      key('iching-line-6'),
      300,
      scrollable: find.descendant(
        of: key('iching-scroll-main'),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('見群龍无首，吉。'), findsOneWidget);
    expect(find.textContaining('All six lines change'), findsOneWidget);

    // The button at the centre of the card's foot.
    final card = tester.getRect(key('iching-reading-card'));
    final button = tester.getRect(key('iching-switch'));
    expect(button.center.dx, closeTo(card.center.dx, 1));
    expect(button.bottom, lessThan(card.bottom));
    expect(button.top, greaterThan(card.bottom - 80));
    expect(turn(tester), 'Becomes 2 坤');

    // Turned: the one it becomes, with the cast's lines read in the
    // hexagram cast.
    await tap(tester, 'iching-switch');
    expect(text(tester, 'iching-name'), '坤');
    expect(key('iching-becomes-lines'), findsOneWidget);
    expect(key('iching-line-0'), findsNothing);
    expect(turn(tester), 'Back to 1 乾');
    // Its other pages are its own.
    await swipe(tester, 3);
    expect(text(tester, 'iching-title-notes'), '2 坤 · NOTES');
    await tap(tester, 'iching-switch');
    expect(text(tester, 'iching-title-notes'), '1 乾 · NOTES');
    await swipe(tester, -3);
    expect(text(tester, 'iching-name'), '乾');
    expect(key('iching-line-0'), findsOneWidget);
  });

  testWidgets('by hand: six lines set from the bottom make the hexagram and '
      'the one it becomes', (tester) async {
    await pump(tester);
    await tap(tester, 'iching-manual');
    expect(subtitle(tester, 'iching-cast-top-bar'), 'Line 1 of 6');
    // A line above the next to be set cannot be set yet.
    await tester.tap(key('iching-manual-3-7'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(subtitle(tester, 'iching-cast-top-bar'), 'Line 1 of 6');
    expect(enabled(tester, 'iching-save'), isFalse);

    // 9, 8, 8, 8, 7, 8 from the bottom: 震 under 坎, 3 屯, its first line
    // changing, so it becomes 坤 under 坎, 8 比.
    const set = [9, 8, 8, 8, 7, 8];
    final cast = YijingCast([for (final n in set) LineValue.of(n)]);
    expect(pack.of(cast.primary).number, 3);
    expect(pack.of(cast.relating).number, 8);
    for (final (place, n) in set.indexed) {
      await tap(tester, 'iching-manual-$place-$n');
    }
    expect(subtitle(tester, 'iching-cast-top-bar'), startsWith('3 · 屯'));
    expect(enabled(tester, 'iching-save'), isTrue);
    expect(key('iching-becomes'), findsNothing);
    expect(find.text('3 屯'), findsOneWidget);
    // Casting afresh at the bottom left, in red; nothing at the centre.
    final body = tester.getRect(find.byType(IchingCastScreen));
    expect(tester.getRect(key('iching-again')).right, lessThan(body.width / 4));
    expect(tester.widget<GlyphButton>(key('iching-again')).tint, dangerColor);
    expect(key('iching-cast'), findsNothing);

    // A line set may be set again: the first at rest, 屯 no longer
    // changes, and its reading has nothing to turn to.
    await tap(tester, 'iching-manual-0-7');
    await tap(tester, 'iching-reading');
    expect(text(tester, 'iching-name'), '屯');
    expect(key('iching-switch'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, 'iching-manual-0-9');

    await tap(tester, 'iching-reading');
    expect(text(tester, 'iching-name'), '屯');
    expect(key('iching-line-0'), findsOneWidget);
    expect(key('iching-line-1'), findsNothing);
    expect(turn(tester), 'Becomes 8 比');
    // A swipe turns the card's pages, not the hexagram.
    await swipe(tester, 3);
    expect(text(tester, 'iching-page-name'), 'NOTES');
    expect(text(tester, 'iching-title-notes'), '3 屯 · NOTES');
    await swipe(tester, -3);
    await tap(tester, 'iching-switch');
    expect(text(tester, 'iching-name'), '比');
    expect(turn(tester), 'Back to 3 屯');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Begun again, every line waits.
    await tap(tester, 'iching-again');
    expect(subtitle(tester, 'iching-cast-top-bar'), 'Line 1 of 6');
    expect(key('iching-again'), findsNothing);
  });

  testWidgets('a reading card shows the Chinese, its sound and our English; '
      'a touch unfolds the rest, another folds it', (tester) async {
    await pump(tester, home: IchingReadingScreen(number: 1, pack: pack));
    final qian = pack.hexagrams.first;
    final reading = qian.readIn(AppLanguage.en)!.reading;
    expect(text(tester, 'iching-name'), '乾');
    expect(text(tester, 'iching-name-sound'), qian.spoken);
    expect(text(tester, 'iching-name-ours'), reading.name);
    if (qian.sound?.name != null) expect(qian.spoken, 'Qián');

    // The header: beside the figure the name, its sound under it, the two
    // as tall as the figure; under them our name, centred and larger.
    final figure = tester.getRect(key('iching-figure'));
    final name = tester.getRect(key('iching-name'));
    final sound = tester.getRect(key('iching-name-sound'));
    final ours = tester.getRect(key('iching-name-ours'));
    expect(name.left, greaterThan(figure.right));
    expect(sound.top, greaterThanOrEqualTo(name.bottom));
    expect(name.top, closeTo(figure.top, 1));
    expect(sound.bottom, closeTo(figure.bottom, 1));
    expect(sound.center.dx, closeTo(name.center.dx, 1));
    expect(ours.top, greaterThan(figure.bottom));
    final page = tester.getRect(key('iching-scroll-main'));
    expect(ours.center.dx, closeTo(page.center.dx, 13));
    expect(
      tester.widget<Text>(key('iching-name-ours')).style!.fontSize,
      greaterThanOrEqualTo(28),
    );

    // Folded: the three, and nothing said of them.
    expect(find.text(qian.judgment), findsOneWidget);
    if (qian.sound?.judgment case final said?) {
      expect(find.text(said), findsOneWidget);
    }
    expect(find.text(reading.judgment), findsOneWidget);
    expect(key('iching-judgment-note'), findsNothing);
    expect(find.text('AS ${reading.traditionBy} READS IT'), findsNothing);
    await tap(tester, 'iching-judgment');
    expect(text(tester, 'iching-judgment-note'), reading.judgmentNote);
    expect(find.text('AS ${reading.traditionBy} READS IT'), findsOneWidget);
    await tap(tester, 'iching-judgment');
    expect(key('iching-judgment-note'), findsNothing);

    expect(find.text(qian.image), findsOneWidget);
    expect(find.text(reading.image), findsOneWidget);
    expect(key('iching-image-note'), findsNothing);
    await tap(tester, 'iching-image');
    expect(find.text('A LATER LAYER OF THE BOOK'), findsOneWidget);
    expect(text(tester, 'iching-image-note'), reading.imageNote);

    // In the library every line, the seventh too, none marked.
    for (var i = 0; i < 7; i++) {
      expect(key('iching-line-$i'), findsOneWidget);
    }
    expect(find.text('初九'), findsOneWidget);
    expect(find.text('用九'), findsOneWidget);
    expect(find.text('CHANGES'), findsNothing);
    expect(key('iching-line-note-0'), findsNothing);
    await tap(tester, 'iching-line-0');
    expect(text(tester, 'iching-line-note-0'), reading.lines.first.note);

    // The notes, the readings and the credit are pages of their own,
    // shown open.
    expect(key('iching-notes'), findsNothing);
    await swipe(tester, 3);
    expect(text(tester, 'iching-page-name'), 'NOTES');
    expect(text(tester, 'iching-name-note'), reading.nameNote);
    expect(key('iching-trigrams'), findsOneWidget);
    await swipe(tester);
    expect(text(tester, 'iching-page-name'), 'READINGS');
    expect(find.text(reading.readings.first.text), findsOneWidget);
    expect(find.textContaining('Kanripo'), findsNothing);
    await swipe(tester);
    expect(text(tester, 'iching-page-name'), 'CREDIT');
    expect(text(tester, 'iching-licence'), 'CC BY-SA 4.0');
    expect(find.textContaining('Kanripo'), findsOneWidget);
  });

  testWidgets('a hexagram from the library is one card of six pages, '
      'shown as the manual shows them, and nothing to turn to', (tester) async {
    await pump(tester, home: IchingLibrary(pack: pack));
    await tap(tester, 'iching-row-3');
    expect(text(tester, 'iching-name'), '屯');
    expect(text(tester, 'iching-page-name'), 'MAIN');
    expect(key('iching-switch'), findsNothing);
    for (var i = 0; i < 6; i++) {
      expect(key('iching-dot-$i'), findsOneWidget);
    }
    expect(key('iching-dot-6'), findsNothing);
    expect(tester.getSize(key('iching-dot-0')).width, 16);

    // The scroll's bar kept clear of the words, as the manual's is: the
    // bar 8 in from the card's line, the words 24 in from the bar.
    final card = tester.getRect(key('iching-reading-card'));
    final words = tester.getRect(key('iching-judgment'));
    final page = tester.getRect(key('iching-scroll-main'));
    expect(card.right - 1 - page.right, 8);
    expect(page.right - words.right, 24);

    // Swiped through its six pages, and no further: never to another
    // hexagram.
    final names = ['WILHELM', 'LEGGE', 'NOTES', 'READINGS', 'CREDIT', 'CREDIT'];
    for (final (i, name) in names.indexed) {
      await swipe(tester);
      expect(text(tester, 'iching-page-name'), name);
      expect(tester.getSize(key('iching-dot-${i.clamp(0, 4) + 1}')).width, 16);
    }
    expect(text(tester, 'iching-title-credit'), '3 屯 · CREDIT');
    expect(tester.getSize(key('iching-dot-0')).width, 6);
    await swipe(tester, -5);
    expect(text(tester, 'iching-name'), '屯');
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(subtitle(tester, 'iching-library-top-bar'), startsWith('3 · 屯'));
  });

  group('the translators', () {
    // The shipped pack with stand-in text of Wilhelm's and Legge's laid
    // into 3 屯 (and 1 乾, with its seven lines), and none elsewhere.
    Map<String, dynamic> translator(String who, int count) => {
      'name': '$who name',
      'judgment': '$who judgment',
      'image': '$who image',
      'lines': [for (var i = 0; i < count; i++) '$who line $i'],
      'source': '$who source',
    };
    final source = jsonDecode(
      File('assets/iching/pack.v2.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final h
        in (source['hexagrams'] as List).cast<Map<String, dynamic>>()) {
      final n = h['n'] as int;
      if (n == 1 || n == 3) {
        h['wilhelm'] = translator('Wilhelm', n == 1 ? 7 : 6);
        h['legge'] = translator('Legge', n == 1 ? 7 : 6);
      } else {
        // The shipped pack has them for all 64: taken out here, so that a
        // hexagram without them can be seen.
        h.remove('wilhelm');
        h.remove('legge');
      }
    }
    final fixture = IchingPack.parse(jsonEncode(source));

    testWidgets('the card pages Main, Wilhelm, Legge, Notes, Readings and '
        'Credit; each translator\'s page gives his text whole', (tester) async {
      await pump(tester, home: IchingReadingScreen(number: 3, pack: fixture));
      expect(text(tester, 'iching-page-name'), 'MAIN');
      for (final (i, who) in ['Wilhelm', 'Legge'].indexed) {
        final page = who.toLowerCase();
        await swipe(tester);
        expect(text(tester, 'iching-page-name'), who.toUpperCase());
        expect(tester.getSize(key('iching-dot-${i + 1}')).width, 16);
        expect(
          text(tester, 'iching-title-$page'),
          '3 屯 · ${who.toUpperCase()} (${i == 0 ? 1924 : 1882})',
        );
        expect(text(tester, 'iching-$page-name'), '$who name');
        expect(find.text('$who judgment'), findsOneWidget);
        expect(find.text('$who image'), findsOneWidget);
        expect(find.text(i == 0 ? 'DAS URTEIL' : 'THE TEXT'), findsOneWidget);
        expect(
          find.text(i == 0 ? 'DAS BILD' : 'THE SYMBOLISM'),
          findsOneWidget,
        );
        // Every line in the library, and his source at the foot.
        for (var line = 0; line < 6; line++) {
          expect(key('iching-$page-line-$line'), findsOneWidget);
        }
        expect(find.text('$who line 5'), findsOneWidget);
        expect(text(tester, 'iching-$page-source'), '$who source');
        // No pinyin here.
        final tones = fixture.hexagrams[2].sound?.judgment;
        if (tones != null) expect(find.text(tones), findsNothing);
      }
      final names = ['NOTES', 'READINGS', 'CREDIT'];
      for (final (i, name) in names.indexed) {
        await swipe(tester);
        expect(text(tester, 'iching-page-name'), name);
        expect(tester.getSize(key('iching-dot-${i + 3}')).width, 16);
      }
      // The credit names both translators.
      expect(find.textContaining('Richard Wilhelm'), findsOneWidget);
      expect(find.textContaining('James Legge'), findsOneWidget);
      expect(
        find.textContaining('Sacred Books of the East 16'),
        findsOneWidget,
      );
    });

    testWidgets('from a cast, a translator\'s page reads only the lines that '
        'change, and the seventh where all six do', (tester) async {
      // 9, 8, 8, 8, 7, 8: 3 屯, its first line changing.
      final cast = YijingCast([
        for (final n in [9, 8, 8, 8, 7, 8]) LineValue.of(n),
      ]);
      await pump(
        tester,
        home: IchingReadingScreen.cast(cast: cast, pack: fixture),
      );
      for (final page in ['wilhelm', 'legge']) {
        await swipe(tester);
        expect(key('iching-$page-line-0'), findsOneWidget);
        for (var line = 1; line < 6; line++) {
          expect(key('iching-$page-line-$line'), findsNothing);
        }
      }
      // Turned to what it becomes, 8 比: its text not in, said quietly.
      await tap(tester, 'iching-switch');
      expect(key('iching-legge-not-yet'), findsOneWidget);
    });

    testWidgets('the copy button beside the page\'s name puts that page '
        'alone on the clipboard as markdown', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      // 9, 8, 8, 8, 7, 8: 3 屯, its first line changing.
      final cast = YijingCast([
        for (final n in [9, 8, 8, 8, 7, 8]) LineValue.of(n),
      ]);
      await pump(
        tester,
        home: IchingReadingScreen.cast(cast: cast, pack: fixture),
      );
      // Beside the page's name, clear of the button at the centre.
      final name = tester.getRect(key('iching-page-name'));
      final copy = tester.getRect(key('iching-copy'));
      expect(copy.left, greaterThan(name.right));
      expect(copy.overlaps(tester.getRect(key('iching-switch'))), isFalse);

      final hexagram = fixture.hexagrams[2];
      await tap(tester, 'iching-copy');
      expect(find.text('Copied.'), findsOneWidget);
      expect(copied, startsWith('# 3 ${hexagram.symbol} 屯'));
      expect(copied, contains('## Judgment\n\n${hexagram.judgment}'));
      expect(copied, contains('### ${hexagram.lines[0].label} · changes'));
      expect(copied, isNot(contains(hexagram.lines[1].label)));
      // The parts that fold open come with it.
      final reading = hexagram.reading(AppLanguage.en)!;
      expect(copied, contains(reading.lines[0].note));
      expect(copied, isNot(contains('Wilhelm judgment')));

      await swipe(tester);
      await tap(tester, 'iching-copy');
      expect(copied, startsWith('# 3 屯 · Wilhelm (1924)'));
      expect(copied, contains('## Das Urteil\n\nWilhelm judgment'));
      expect(copied, contains('Wilhelm line 0'));
      expect(copied, isNot(contains('Wilhelm line 1')));
      expect(copied, isNot(contains(hexagram.judgment)));

      await swipe(tester, 2);
      await tap(tester, 'iching-copy');
      expect(copied, startsWith('# 3 屯 · Notes'));
      expect(copied, contains(reading.nameNote));

      // Turned to what it becomes, the page copied is its own.
      await tap(tester, 'iching-switch');
      await tap(tester, 'iching-copy');
      expect(copied, startsWith('# 8 比 · Notes'));
    });

    testWidgets('a line that changes glows in the accent, with no ring or '
        'cross', (tester) async {
      final cast = YijingCast([
        for (final n in [9, 8, 8, 8, 7, 6]) LineValue.of(n),
      ]);
      await pump(
        tester,
        home: IchingReadingScreen.cast(cast: cast, pack: fixture),
      );
      final colors = SmTheme.of(tester.element(key('iching-figure'))).colors;
      // Brighter than the accent: taken toward white, the lines being light.
      final lit = Color.lerp(colors.accent, const Color(0xFFFFFFFF), 0.15)!;
      final figure = tester.renderObject(
        find.descendant(
          of: key('iching-figure'),
          matching: find.byType(CustomPaint),
        ),
      );
      // Bottom up: the nine glowing in the accent, then the still lines,
      // then the six at the top glowing, both halves.
      expect(
        figure,
        paints
          ..line(color: colors.accent.withValues(alpha: 0.8))
          ..line(color: colors.accent)
          ..line(color: lit)
          ..line(color: colors.textPrimary)
          ..line(color: colors.textPrimary)
          ..line(color: colors.textPrimary)
          ..line(color: colors.textPrimary)
          ..line(color: colors.textPrimary)
          ..line(color: colors.textPrimary)
          ..line(color: colors.textPrimary)
          ..line(color: colors.accent.withValues(alpha: 0.8))
          ..line(color: colors.accent.withValues(alpha: 0.8))
          ..line(color: colors.accent)
          ..line(color: colors.accent)
          ..line(color: lit)
          ..line(color: lit),
      );
      expect(figure, isNot(paints..circle()));
    });

    testWidgets('our notes are kept back by default: no Notes, no Readings, '
        'nothing unfolds on Main, and nothing of them is copied', (
      tester,
    ) async {
      IchingDrafts.shown.value = false;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pump(tester, home: IchingReadingScreen(number: 3, pack: fixture));
      // Four dots: Main, Wilhelm, Legge, Credit.
      expect(find.byKey(const ValueKey('iching-dot-3')), findsNothing);
      expect(find.byKey(const ValueKey('iching-dot-4')), findsNothing);
      final reading = fixture.hexagrams[2].reading(AppLanguage.en)!;
      await tap(tester, 'iching-judgment');
      expect(key('iching-judgment-note'), findsNothing);
      await tap(tester, 'iching-copy');
      expect(copied, contains(reading.judgment));
      expect(copied, isNot(contains(reading.judgmentNote)));
      expect(copied, isNot(contains(reading.lines[0].note)));
      final names = ['WILHELM', 'LEGGE', 'CREDIT'];
      for (final name in names) {
        await swipe(tester);
        expect(text(tester, 'iching-page-name'), name);
      }
      // Shown again (the owner's switch): the pages come back.
      IchingDrafts.shown.value = true;
      await tester.pumpAndSettle();
      expect(text(tester, 'iching-page-name'), 'MAIN');
      expect(find.byKey(const ValueKey('iching-dot-4')), findsOneWidget);
    });

    testWidgets('all six changing, 乾 reads every line and 用九', (tester) async {
      final cast = YijingCast([for (var i = 0; i < 6; i++) LineValue.of(9)]);
      await pump(
        tester,
        home: IchingReadingScreen.cast(cast: cast, pack: fixture),
      );
      await swipe(tester);
      for (var line = 0; line < 7; line++) {
        expect(key('iching-wilhelm-line-$line'), findsOneWidget);
      }
      expect(find.text('用九'), findsOneWidget);
    });

    testWidgets('where his text is not in yet the page says so', (
      tester,
    ) async {
      await pump(tester, home: IchingReadingScreen(number: 4, pack: fixture));
      await swipe(tester);
      expect(key('iching-wilhelm-not-yet'), findsOneWidget);
      expect(text(tester, 'iching-title-wilhelm'), '4 蒙 · WILHELM (1924)');
      await swipe(tester);
      expect(key('iching-legge-not-yet'), findsOneWidget);
    });
  });

  testWidgets('a hexagram not yet translated gives its Chinese, and says so', (
    tester,
  ) async {
    final notYet = pack.hexagrams
        .where((h) => h.reading(AppLanguage.en) == null)
        .firstOrNull;
    if (notYet == null) return;
    await pump(
      tester,
      home: IchingReadingScreen(number: notYet.number, pack: pack),
    );
    expect(find.text(notYet.judgment), findsOneWidget);
    expect(key('iching-not-yet'), findsOneWidget);
    expect(text(tester, 'iching-name-sound'), notYet.spoken);
  });

  testWidgets('in Indonesian, a hexagram with only the English reads it, '
      'with a faint word that the Indonesian is not done', (tester) async {
    final borrowed = pack.hexagrams
        .where((h) => h.readIn(AppLanguage.id)?.borrowed ?? false)
        .firstOrNull;
    if (borrowed == null) return;
    await pump(
      tester,
      language: AppLanguage.id,
      home: IchingReadingScreen(number: borrowed.number, pack: pack),
    );
    expect(key('iching-no-indonesian'), findsOneWidget);
    expect(
      find.text(borrowed.reading(AppLanguage.en)!.judgment),
      findsOneWidget,
    );
    expect(find.text('PUTUSAN'), findsOneWidget);
    for (final fold in ['judgment', 'image']) {
      await tap(tester, 'iching-$fold');
      expect(tester.takeException(), isNull);
    }
    for (final name in ['WILHELM', 'LEGGE', 'CATATAN', 'TAFSIR', 'KREDIT']) {
      await swipe(tester);
      expect(text(tester, 'iching-page-name'), name);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a cast is saved to the journal only when its entry is, and '
      'loaded back from it', (tester) async {
    await pump(tester, coins: [true, true, true, true, false, false]);
    await tap(tester, 'iching-coins');
    final journal = journalOf(tester);
    final category = journal.categories.first;

    // Nothing in the journal yet: the list says so.
    await tap(tester, 'iching-load');
    expect(key('iching-load-none'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(key('iching-load-none'), findsNothing);
    expect(find.byType(IchingCastScreen), findsOneWidget);

    // Nine, then seven, by turns: 乾 with three changing lines.
    await castSix(tester);
    final cast = YijingCast([
      for (final n in [9, 7, 9, 7, 9, 7]) LineValue.of(n),
    ]);
    final primary = pack.of(cast.primary);
    final relating = pack.of(cast.relating);
    await tap(tester, 'iching-save');
    await tap(tester, 'iching-save-${category.id}');
    expect(find.byType(EntryScreen), findsOneWidget);
    expect(journal.allEntries().where((e) => e.iching != null), isEmpty);
    expect(key('entry-iching-card'), findsOneWidget);
    await tester.enterText(key('entry-content'), 'Whether to move.');
    await tester.tap(key('entry-save'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Written to the journal.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
    final saved = journal.allEntries().where((e) => e.iching != null).single;
    expect(
      saved.title,
      '${primary.number} ${primary.name} → '
      '${relating.number} ${relating.name}',
    );
    expect(saved.content, 'Whether to move.');
    final record = IchingRecord.parse(saved.iching)!;
    expect(record.method, CastMethod.coins);
    expect(record.lines, cast.lines);
    // Dated by the moment it was cast.
    expect(saved.date, record.date);
    expect(saved.minuteOfDay, record.minute);

    // Back to the cast, and cast afresh; then the saved one loaded back.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, 'iching-again');
    expect(key('iching-again'), findsNothing);
    await tap(tester, 'iching-load');
    expect(key('iching-load-${saved.id}'), findsOneWidget);
    await tap(tester, 'iching-load-${saved.id}');
    expect(find.text('Cast from ${saved.title} loaded'), findsOneWidget);
    expect(key('iching-entry-capsule'), findsOneWidget);
    expect(key('iching-again'), findsOneWidget);
    expect(
      subtitle(tester, 'iching-cast-top-bar'),
      startsWith('${primary.number} · ${primary.name}'),
    );
    // The entry's: discard and save here in place of load and save.
    expect(key('iching-load'), findsNothing);
    expect(key('iching-discard'), findsOneWidget);
    expect(key('iching-becomes'), findsNothing);

    // Saving the very cast again asks to save it here or as new.
    await tap(tester, 'iching-save');
    expect(key('iching-save-ask'), findsOneWidget);
    await tap(tester, 'iching-cancel');
    expect(key('iching-save-ask'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('a cast unreadable is listed faint and cannot be loaded', (
    tester,
  ) async {
    await pump(tester);
    final journal = journalOf(tester);
    final broken = journal.save(
      Entry(
        id: '',
        date: CivilDate(2026, 10, 20),
        minuteOfDay: 9 * 60,
        utcOffset: offset,
        categoryId: journal.categories.first.id,
        title: 'Broken',
        content: '',
        iching: 'v1 method=coins lines=7',
      ),
    );
    await tap(tester, 'iching-stalks');
    await tap(tester, 'iching-load');
    expect(find.text('Cannot be read back'), findsOneWidget);
    await tester.tap(key('iching-load-${broken.id}'));
    await tester.pumpAndSettle();
    expect(key('iching-load-list'), findsOneWidget);
    expect(key('iching-entry-capsule'), findsNothing);
  });

  testWidgets('an entry\'s cast opens by a touch, standing whole, and is '
      'cast afresh into its place', (tester) async {
    await pump(tester);
    final journal = journalOf(tester);
    final record = IchingRecord(
      method: CastMethod.stalks,
      lines: [
        for (final n in [8, 8, 8, 8, 8, 8]) LineValue.of(n),
      ],
      date: CivilDate(2026, 10, 24),
      minute: 19 * 60 + 5,
      offset: offset,
    );
    final entry = journal.save(
      Entry(
        id: '',
        date: record.date,
        minuteOfDay: record.minute,
        utcOffset: offset,
        categoryId: journal.categories.first.id,
        title: '2 坤',
        content: 'Asked about the house.',
        iching: record.value,
      ),
    );
    await pump(
      tester,
      coins: [true, false, false],
      home: EntryScreen(
        date: entry.date,
        utcOffset: entry.utcOffset,
        entry: entry,
      ),
    );
    final mine = journalOf(tester).save(entry.copyWith());
    await pump(
      tester,
      home: EntryScreen(
        date: mine.date,
        utcOffset: mine.utcOffset,
        entry: mine,
      ),
    );
    expect(key('entry-iching-card'), findsOneWidget);
    expect(find.textContaining('Stalks · 24 October 2026 · 19:05'), findsOne);
    expect(
      find.descendant(of: key('entry-iching-card'), matching: find.text('2 坤')),
      findsOneWidget,
    );
    await tester.tap(key('entry-iching-card'));
    await tester.pumpAndSettle();
    expect(find.byType(IchingCastScreen), findsOneWidget);
    expect(find.text('Cast from 2 坤 loaded'), findsOneWidget);
    expect(key('iching-again'), findsOneWidget);
    expect(subtitle(tester, 'iching-cast-top-bar'), startsWith('2 · 坤'));
    // Discard, opened from the entry: back to it, nothing changed.
    await tap(tester, 'iching-discard');
    expect(key('iching-discard-ask'), findsOneWidget);
    await tap(tester, 'iching-discard-yes');
    expect(find.byType(IchingCastScreen), findsNothing);
    expect(find.byType(EntryScreen), findsOneWidget);
    expect(
      journalOf(tester).allEntries().firstWhere((e) => e.id == mine.id).iching,
      record.value,
    );
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Opened again, cast afresh, and saved into the entry's place: back
    // to the entry, which says so. Its writing stays; its title, still
    // the one the cast gave it, follows the new cast.
    await tester.tap(key('entry-iching-card'));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tap(tester, 'iching-again');
    expect(enabled(tester, 'iching-save'), isFalse);
    await castSix(tester);
    await tap(tester, 'iching-save');
    expect(key('iching-save-ask'), findsOneWidget);
    await tester.tap(key('iching-save-here'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(IchingCastScreen), findsNothing);
    expect(find.text('The entry was changed.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
    final changed = journalOf(tester)
        .allEntries()
        .firstWhere((e) => e.id == mine.id);
    final cast = IchingRecord.parse(changed.iching)!.cast;
    expect(changed.iching, isNot(record.value));
    expect(changed.content, 'Asked about the house.');
    expect(changed.title, startsWith('${pack.of(cast.primary).number} '));
    expect(changed.date, entry.date);
  });

  testWidgets('the library: the number wheel and the trigram wheels choose '
      'the hexagram, light its row and bring it into sight', (tester) async {
    await pump(tester, home: IchingLibrary(pack: pack));
    expect(subtitle(tester, 'iching-library-top-bar'), startsWith('1 · 乾'));
    await tester.drag(key('iching-wheel-number'), const Offset(0, -36 * 2));
    await tester.pumpAndSettle();
    expect(subtitle(tester, 'iching-library-top-bar'), startsWith('3 · 屯'));

    await tester.drag(key('iching-wheel-number'), const Offset(0, -36 * 37));
    await tester.pumpAndSettle();
    expect(subtitle(tester, 'iching-library-top-bar'), startsWith('40 · 解'));
    // Far down the list, its row brought into sight.
    final rows = tester.getRect(key('iching-library-rows'));
    final row = tester.getRect(key('iching-row-40'));
    expect(rows.contains(row.center), isTrue);

    // By trigrams: the wheels stand on 40 解's, 震 above 坎. The upper
    // turned on two notches, to 坎, makes 29 坎.
    await tap(tester, 'iching-library-tab-trigrams');
    expect(find.text('UPPER'), findsOneWidget);
    expect(find.text('LOWER'), findsOneWidget);
    await tester.drag(key('iching-wheel-upper'), const Offset(0, -36 * 2));
    await tester.pumpAndSettle();
    expect(subtitle(tester, 'iching-library-top-bar'), startsWith('29 · 坎'));
    // Upper 坎, lower 震: 3 屯.
    await tester.drag(key('iching-wheel-lower'), const Offset(0, 36 * 2));
    await tester.pumpAndSettle();
    expect(subtitle(tester, 'iching-library-top-bar'), startsWith('3 · 屯'));

    // The chosen one opened, by the panel's button; and a row by a touch.
    await tap(tester, 'iching-library-open');
    expect(find.byType(IchingReadingScreen), findsOneWidget);
    expect(text(tester, 'iching-name'), '屯');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, 'iching-row-1');
    expect(text(tester, 'iching-name'), '乾');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(subtitle(tester, 'iching-library-top-bar'), startsWith('1 · 乾'));
  });

  testWidgets('the stalks cast a line in three changes', (tester) async {
    await pump(tester);
    await tap(tester, 'iching-stalks');
    await tester.tap(key('iching-cast'));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(tester.takeException(), isNull);
    // Mid-count nothing is announced yet.
    expect(text(tester, 'iching-value'), '');
    await tester.pumpAndSettle();
    expect([
      for (final v in LineValue.values)
        const Strings(AppLanguage.en).ichingLineValue(v),
    ], contains(text(tester, 'iching-value')));
  });

  testWidgets('speaks Indonesian, and fits on its side', (tester) async {
    await pump(tester, language: AppLanguage.id, size: const Size(3040, 1440));
    expect(find.text('KOIN'), findsOneWidget);
    await tap(tester, 'iching-manual');
    for (var place = 0; place < 6; place++) {
      await tap(tester, 'iching-manual-$place-${place.isEven ? 9 : 8}');
    }
    expect(tester.takeException(), isNull);
    // Nines change: the reading's button to what it becomes, and back.
    await tap(tester, 'iching-reading');
    expect(turn(tester), startsWith('Menjadi '));
    await tap(tester, 'iching-switch');
    expect(turn(tester), startsWith('Kembali ke '));
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, 'iching-coins');
    await castSix(tester);
    expect(tester.takeException(), isNull);
    await tap(tester, 'iching-reading');
    for (final fold in ['judgment', 'image']) {
      await tap(tester, 'iching-$fold');
      expect(tester.takeException(), isNull);
    }
    await swipe(tester, 3);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, 'iching-read');
    await tap(tester, 'iching-library-tab-trigrams');
    expect(tester.takeException(), isNull);
  });
}
