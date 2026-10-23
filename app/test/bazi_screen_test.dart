import 'dart:io';

import 'package:candra/app_shell.dart';
import 'package:candra/bazi/bazi_places.dart';
import 'package:candra/bazi/bazi_record.dart';
import 'package:candra/glyph_button.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_file.dart';
import 'package:sm_design/sm_design.dart';
import 'package:candra/bazi/bazi_screen.dart';
import 'package:candra/bazi/bazi_tables.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  const offset = Duration(hours: 7);
  final day = CivilDate(2026, 10, 12);
  Finder key(String name) => find.byKey(ValueKey(name));

  // The tables as the app ships them.
  final tables = BaziTables.parse(
    File('assets/bazi/hidden_stems.ziping.v1.json').readAsStringSync(),
    File('assets/bazi/relations.ziping.v1.json').readAsStringSync(),
  );

  // Every table, as the app ships them.
  final library = BaziLibrary(
    [
      for (final id in BaziLibrary.hiddenStemFiles)
        File('assets/bazi/hidden_stems.$id.json').readAsStringSync(),
    ],
    [
      for (final id in BaziLibrary.relationFiles)
        File('assets/bazi/relations.$id.json').readAsStringSync(),
    ],
  );

  final places = BaziPlaces.parse(
    File('assets/bazi/zone_places.v1.json').readAsStringSync(),
  );

  Future<void> pump(
    WidgetTester tester, {
    int minute = 10 * 60,
    CivilDate? date,
    String? zone,
    bool everyTable = false,
    AppLanguage language = AppLanguage.en,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: language),
        home:
            home ??
            BaziScreen(
              date: date ?? day,
              utcOffset: offset,
              minuteOfDay: minute,
              tables: everyTable ? null : tables,
              library: everyTable ? library : null,
              places: places,
              zone: zone,
            ),
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

  // The Options tab, last in the strip of fields: the strip is drawn
  // along to it first.
  Future<void> options(WidgetTester tester) async {
    await tester.dragUntilVisible(
      key('bazi-field-options'),
      key('bazi-fields'),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'bazi-field-options');
  }

  // One of the chart's cards to and from the journal, under the Options
  // tab of the lower panel (what was in the bar): the tab first if the
  // cards are not up.
  Future<void> card(WidgetTester tester, String name) async {
    if (key(name).evaluate().isEmpty) await options(tester);
    await tap(tester, name);
  }

  // The glyph a card of the Options tab shows.
  Glyph cardGlyph(WidgetTester tester, String name) => tester
      .widget<GlyphMark>(
        find.descendant(of: key(name), matching: find.byType(GlyphMark)),
      )
      .glyph;

  // Back, as the phone's: closes what the Options' cards opened.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  // The stem and branch written on a pillar.
  String pillar(WidgetTester tester, String which) {
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: key('pillar-$which'),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .whereType<String>()
        .where((t) => t.length == 1)
        .toList();
    return texts.take(2).join();
  }

  group('the tables the app ships', () {
    test('give every branch its hidden stems, principal first', () {
      String hidden(Branch branch) =>
          tables.hiddenStems[branch]!.map((s) => s.hanzi).join();
      expect(Branch.values.map(hidden), [
        '癸',
        '己癸辛',
        '甲丙戊',
        '乙',
        '戊乙癸',
        '丙戊庚',
        '丁己',
        '己丁乙',
        '庚壬戊',
        '辛',
        '戊辛丁',
        '壬甲',
      ]);
      // A branch's own element is its principal stem's.
      expect(tables.elementOf(Branch.zi), Unsur.air);
      expect(tables.elementOf(Branch.chou), Unsur.tanah);
      expect(tables.elementOf(Branch.shen), Unsur.logam);
    });

    test('say whose they are, and what they were checked against', () {
      expect(tables.hidden.lineage, contains('淵海子平'));
      expect(tables.hidden.verified, isTrue);
      expect(tables.hidden.notes, contains('transcription'));
      expect(tables.relations.lineage, contains('三命通會'));
    });

    test('come in more than one lineage, and the lineages differ', () {
      final command = library.tables(1, 0);
      expect(command.hidden.id, 'siling.v1');
      expect(command.hidden.verified, isFalse);
      // The month-command table gives a turn to stems the verse leaves
      // out, and still puts the principal first.
      expect(command.hiddenStems[Branch.zi]!.map((s) => s.hanzi).join(), '癸壬');
      expect(command.hiddenStems[Branch.wu]!.map((s) => s.hanzi).join(), '丁丙己');
      expect(tables.command, isNull);
      for (final branch in Branch.values) {
        expect(
          command.hiddenStems[branch]!.first,
          tables.hiddenStems[branch]!.first,
        );
        expect(command.hiddenStems[branch]!.toSet(), {
          for (final (stem, _) in command.command![branch]!) stem,
        });
        // Every month is divided into thirty days.
        expect(
          command.command![branch]!.fold(0, (sum, turn) => sum + turn.$2),
          30,
        );
      }
      // The tiger month: 戊 seven days, 丙 seven, then 甲.
      Stem? at(double days) => command.commanding(
        Branch.yin,
        Duration(minutes: (days * 1440).round()),
      );
      expect(at(0)!.hanzi, '戊');
      expect(at(6.9)!.hanzi, '戊');
      expect(at(7.1)!.hanzi, '丙');
      expect(at(14.1)!.hanzi, '甲');
      expect(at(30.9)!.hanzi, '甲');
      expect(tables.commanding(Branch.yin, Duration.zero), isNull);

      // Yuanhai Ziping names the first two punishments the other way
      // round; Ren Tieqiao has none, nor harms.
      final sanming = library.tables(0, 0);
      final yuanhai = library.tables(0, 1);
      final ren = library.tables(0, 2);
      expect(sanming.punishments.first.name, '無恩之刑');
      expect(yuanhai.punishments.first.name, '恃勢之刑');
      expect(
        yuanhai.punishments.first.branches,
        sanming.punishments.first.branches,
      );
      expect(yuanhai.harms, sanming.harms);
      expect(ren.punishments, isEmpty);
      expect(ren.harms, isEmpty);
      const chart = [Branch.zi, Branch.mao, Branch.wei, Branch.wu];
      expect(
        relationsAmong(chart, sanming).map((r) => r.kind),
        containsAll([BaziTerms.punishment, BaziTerms.harm]),
      );
      expect(
        relationsAmong(chart, ren).map((r) => r.kind),
        isNot(anyOf(contains(BaziTerms.punishment), contains(BaziTerms.harm))),
      );
    });

    test('find the relations among four branches', () {
      String found(List<Branch> branches) => relationsAmong(branches, tables)
          .map((r) => '${r.branches.map((b) => b.hanzi).join()}${r.kind.hanzi}')
          .join(' ');
      expect(
        found([Branch.zi, Branch.wu, Branch.chou, Branch.wei]),
        '子午冲 子丑六合 子未害 午丑害 午未六合 丑未冲 丑未刑',
      );
      expect(
        found([Branch.shen, Branch.zi, Branch.chen, Branch.chen]),
        contains('子辰申三合'),
      );
      expect(
        found([Branch.yin, Branch.si, Branch.mao, Branch.mao]),
        contains('寅巳刑'),
      );
      expect(
        found([Branch.wu, Branch.wu, Branch.zi, Branch.mao]),
        contains('午午刑'),
      );
      expect(
        found([Branch.yin, Branch.mao, Branch.chen, Branch.xu]),
        isNot(contains('三合')),
      );
    });
  });

  group('the translation tables', () {
    test('have every stem, branch, god and term, in every tongue', () {
      expect(BaziTerms.stems, hasLength(10));
      expect(BaziTerms.branches, hasLength(12));
      expect(BaziTerms.tenGods, hasLength(10));
      expect(BaziTerms.solarTerms, hasLength(24));
      for (final term in [
        ...BaziTerms.stems,
        ...BaziTerms.branches,
        ...BaziTerms.tenGods,
        ...BaziTerms.solarTerms,
      ]) {
        expect(term.hanzi, isNotEmpty);
        expect(term.pinyin, isNotEmpty);
        expect(term.english, isNotEmpty);
        expect(term.indonesian, isNotEmpty);
      }
      // Stems, branches and solar terms have a Hokkien reading each.
      for (final term in [
        ...BaziTerms.stems,
        ...BaziTerms.branches,
        ...BaziTerms.solarTerms,
      ]) {
        expect(term.hokkien, isNotEmpty, reason: term.hanzi);
      }
      for (var i = 0; i < 10; i++) {
        expect(BaziTerms.stems[i].hanzi, Stem.values[i].hanzi);
        expect(BaziTerms.tenGods[i].hanzi, TenGod.values[i].hanzi);
      }
      for (var i = 0; i < 12; i++) {
        expect(BaziTerms.branches[i].hanzi, Branch.values[i].hanzi);
      }
      expect(BaziTerms.solarTerm(315).hanzi, '立春');
      expect(BaziTerms.solarTerm(195).hanzi, '寒露');
      expect(BaziTerms.solarTerm(270).hanzi, '冬至');
      expect(BaziTerms.solarTerm(0).hanzi, '春分');
    });
  });

  group('the bazi chart', () {
    testWidgets('shows the four pillars of the instant, hour to year, with '
        'the day master marked', (tester) async {
      await pump(tester);
      // 12 October 2026, 10:00 at UTC+7.
      expect(pillar(tester, 'year'), '丙午');
      expect(pillar(tester, 'month'), '戊戌');
      expect(pillar(tester, 'day'), '己未');
      expect(pillar(tester, 'hour'), '己巳');
      // Written hour, day, month, year, left to right.
      final order = [
        'hour',
        'day',
        'month',
        'year',
      ].map((p) => tester.getRect(key('pillar-$p')).left).toList();
      expect(order, [...order]..sort());
      expect(
        find.descendant(of: key('pillar-day'), matching: find.text('日主')),
        findsOneWidget,
      );
      // The year's stem, bing, is the direct seal of a ji day master.
      expect(
        find.descendant(of: key('pillar-year'), matching: find.text('正印')),
        findsOneWidget,
      );
      // The terms either side, in local time.
      expect(
        tester.widget<Text>(key('bazi-term-before')).data,
        allOf(contains('寒露 Cold Dew'), contains('8 October 2026 · 13:2')),
      );
      expect(
        tester.widget<Text>(key('bazi-term-after')).data,
        contains('立冬 Start of Winter'),
      );
      // With no place, it says it is reading the clock.
      expect(
        tester.widget<Text>(key('bazi-time-note')).data,
        contains('No longitude given'),
      );
      // And whose tables these are, and that nothing is kept.
      expect(
        tester.widget<Text>(key('bazi-lineage')).data,
        allOf(
          contains('Ziping'),
          contains('三命通會'),
          contains('Nothing here is kept'),
        ),
      );
    });

    testWidgets('gives each pillar its nayin, counts the elements, and '
        'names the void', (tester) async {
      await pump(tester);
      // 丙午 戊戌 己未 己巳.
      for (final (which, nayin) in [
        ('year', '天河水'),
        ('month', '平地木'),
        ('day', '天上火'),
        ('hour', '大林木'),
      ]) {
        expect(
          find.descendant(of: key('pillar-$which'), matching: find.text(nayin)),
          findsOneWidget,
        );
      }
      expect(
        tester.widget<Text>(key('bazi-elements')).textSpan!.toPlainText(),
        allOf(contains('木 0'), contains('火 3'), contains('土 5')),
      );
      // The day is in the week of 甲寅, which stops short of 子 and 丑.
      expect(
        tester.widget<Text>(key('bazi-void')).data,
        '子丑 · none in this chart',
      );
      // At one in the morning the hour is 丑, and falls in it.
      await tester.drag(key('picker-hour'), const Offset(0, 36 * 9));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(key('bazi-void')).data, '子丑 · hour');
      // 甲子 hour against the day's 己: the two stems combine.
      await tester.drag(key('picker-hour'), const Offset(0, 36));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('甲己  五合 Stem Combination · 土'),
        findsOneWidget,
      );
    });

    testWidgets('roams: the time and the date change the chart at once', (
      tester,
    ) async {
      await pump(tester);
      await tester.drag(key('picker-hour'), const Offset(0, -36 * 3));
      await tester.pumpAndSettle();
      // 13:00 is the wei hour.
      expect(pillar(tester, 'hour'), '辛未');
      await tap(tester, 'bazi-field-date');
      await tester.drag(key('picker-day'), const Offset(0, -36));
      await tester.pumpAndSettle();
      expect(pillar(tester, 'day'), '庚申');
      expect(find.textContaining('13 October 2026'), findsOneWidget);
    });

    testWidgets('with a place, reads the day and hour from the sun and '
        'says by how much', (tester) async {
      await pump(tester, minute: 11 * 60 + 10);
      expect(pillar(tester, 'hour'), '庚午');
      await tap(tester, 'bazi-field-place');
      // From the zone's own meridian, 105 E, seven degrees west: Medan's
      // side of it.
      for (var i = 0; i < 7; i++) {
        await tester.tap(key('bazi-longitude-down'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(key('bazi-longitude-value')).data, '98.0° E');
      // 28 minutes west, and the sundial 14 ahead in mid-October.
      expect(
        tester.widget<Text>(key('bazi-time-note')).data,
        allOf(contains('Clock 11:10 is 10:5'), contains('−1')),
      );
      expect(pillar(tester, 'hour'), '己巳');

      // By the clock rule it is read from the clock again.
      await tap(tester, 'bazi-field-rules');
      // The first rule is the time; the clock is the third way to take it.
      await tester.drag(key('bazi-rules-second-0'), const Offset(0, -36 * 2));
      await tester.pumpAndSettle();
      expect(pillar(tester, 'hour'), '庚午');
      expect(
        tester.widget<Text>(key('bazi-time-note')).data,
        contains('by your choice of rule'),
      );
    });

    testWidgets('placed in a zone, reads the clock as that zone kept it '
        'then, not as it keeps it now', (tester) async {
      // Java under occupation ran on Tokyo's clock.
      await pump(
        tester,
        date: CivilDate(1943, 6, 15),
        minute: 12 * 60,
        zone: 'Asia/Jakarta',
      );
      expect(
        tester.widget<Text>(key('bazi-zone-note')).data,
        'Clocks in Jakarta kept UTC+09:00 then.',
      );
      expect(find.textContaining('UTC+09:00'), findsNWidgets(2));
      // Noon on that clock was 10:07 by the sun over Jakarta: the si
      // hour, where a chart worked from today's UTC+7 would say wu.
      expect(
        tester.widget<Text>(key('bazi-time-note')).data,
        contains('Clock 12:00 is 10:07'),
      );
      expect(pillar(tester, 'hour').substring(1), '巳');
    });

    testWidgets('the wheels choose the zone, and its city gives the '
        'longitude', (tester) async {
      await pump(tester, zone: 'Asia/Jakarta');
      await tap(tester, 'bazi-field-place');
      expect(tester.widget<Text>(key('bazi-longitude-value')).data, '106.8° E');
      final regions = ['UTC', ...places.regions];
      final cities = places.zonesIn('Asia');
      final from = cities.indexOf('Asia/Jakarta');
      final to = cities.indexOf('Asia/Jayapura');
      await tester.drag(
        key('picker-place-second-${regions.indexOf("Asia")}'),
        Offset(0, -36.0 * (to - from)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(key('bazi-zone-note')).data,
        'Clocks in Jayapura kept UTC+09:00 then.',
      );
      expect(tester.widget<Text>(key('bazi-longitude-value')).data, '140.7° E');

      // The first region is no place, only an offset from Greenwich.
      await tester.drag(
        key('picker-place-first'),
        Offset(0, 36.0 * regions.indexOf('Asia')),
      );
      await tester.pumpAndSettle();
      expect(key('bazi-zone-note'), findsNothing);
      expect(find.textContaining('UTC+09:00'), findsOneWidget);
      await tester.drag(
        key('picker-place-second-0'),
        const Offset(0, 36.0 * 2),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('UTC+08:30'), findsOneWidget);
    });

    testWidgets('another table can be chosen under Rules, and the chart '
        'and its note of whose tables follow', (tester) async {
      await pump(tester, everyTable: true);
      expect(key('bazi-command'), findsNothing);
      expect(
        tester.widget<Text>(key('bazi-lineage')).data,
        allOf(contains('又地支藏遁歌'), contains('三命通會')),
      );
      await tap(tester, 'bazi-field-rules');
      // The sixth rule is the hidden stems' table.
      await tester.drag(key('bazi-rules-first'), const Offset(0, -36 * 5));
      await tester.pumpAndSettle();
      await tester.drag(key('bazi-rules-second-5'), const Offset(0, -36));
      await tester.pumpAndSettle();
      // 12 October is the fourth day of the dog month: 辛 commands its
      // first nine.
      expect(
        tester.widget<Text>(key('bazi-command')).textSpan!.toPlainText(),
        '辛 9   丁 3   戊 18   · day 4',
      );
      expect(
        tester.widget<Text>(key('bazi-lineage')).data,
        allOf(contains('人元司令分野'), contains('not checked against the text')),
      );
      // And the seventh, of punishments and harms: Ren Tieqiao's has
      // none.
      expect(find.textContaining('刑 Punishment'), findsWidgets);
      await tester.drag(key('bazi-rules-first'), const Offset(0, -36));
      await tester.pumpAndSettle();
      await tester.drag(key('bazi-rules-second-6'), const Offset(0, -36 * 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('刑 Punishment'), findsNothing);
      expect(tester.widget<Text>(key('bazi-lineage')).data, contains('滴天髓闡微'));
    });

    testWidgets('in the hour before midnight says schools differ, and a '
        'tap shows the other reading', (tester) async {
      await pump(tester, minute: 23 * 60 + 30);
      expect(pillar(tester, 'day'), '己未');
      expect(pillar(tester, 'hour'), '丙子');
      expect(
        find.textContaining(
          'By this rule the day is 己未; by the other it is 庚申',
        ),
        findsOneWidget,
      );
      await tap(tester, 'bazi-late-zi');
      expect(pillar(tester, 'day'), '庚申');
      expect(pillar(tester, 'hour'), '丙子');
      expect(
        find.textContaining(
          'By this rule the day is 庚申; by the other it is 己未',
        ),
        findsOneWidget,
      );
    });

    testWidgets('at any other hour has nothing to say about schools', (
      tester,
    ) async {
      await pump(tester);
      expect(key('bazi-late-zi'), findsNothing);
    });

    testWidgets('shows the luck pillars once a sex is given', (tester) async {
      await pump(tester);
      expect(key('bazi-luck'), findsNothing);
      expect(find.textContaining('Choose one under Sex'), findsOneWidget);
      await tap(tester, 'bazi-field-sex');
      await tap(tester, 'bazi-sex-true');
      // A yang year and a man: forward, from Lidong.
      expect(
        tester.widget<Text>(key('bazi-luck-start')).data,
        startsWith('Forward, from age 8 y'),
      );
      expect(
        find.descendant(of: key('bazi-luck'), matching: find.text('己亥')),
        findsOneWidget,
      );
      await tap(tester, 'bazi-sex-false');
      expect(
        tester.widget<Text>(key('bazi-luck-start')).data,
        startsWith('Backward, from age 1 y'),
      );
      // In whole years, as some lineages give it.
      await tap(tester, 'bazi-field-rules');
      await tester.drag(key('bazi-rules-first'), const Offset(0, -36 * 4));
      await tester.pumpAndSettle();
      await tester.drag(key('bazi-rules-second-4'), const Offset(0, -36));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(key('bazi-luck-start')).data,
        'Backward, from age 1, ten years each',
      );
      await tester.drag(key('bazi-rules-second-4'), const Offset(0, -36));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(key('bazi-luck-start')).data,
        startsWith('Backward, from about age '),
      );
      expect(
        find.descendant(of: key('bazi-luck'), matching: find.text('丁酉')),
        findsOneWidget,
      );
    });

    test('a chart\'s inputs are read back whole, or not at all', () {
      final record = BaziRecord(
        date: CivilDate(1990, 2, 3),
        minute: 23 * 60 + 15,
        offset: const Duration(hours: 7),
        zone: 'Asia/Jakarta',
        longitude: 110.4,
        male: false,
        config: const BaziConfig(
          ziHourRule: ZiHourRule.unified,
          luckRounding: LuckRounding.nearestYear,
        ),
        hidden: 'siling.v1',
        relations: 'renshi.v1',
      );
      final back = BaziRecord.parse(record.value)!;
      expect(back.value, record.value);
      expect(back.config.ziHourRule, ZiHourRule.unified);
      expect(back.male, isFalse);
      // Anything missing or impossible, and it is not read.
      final value = record.value;
      for (final broken in [
        value.replaceFirst(' time=23:15', ''),
        value.replaceFirst('date=1990-02-03', 'date=1990-02-31'),
        value.replaceFirst('zi=unified', 'zi=sometimes'),
        value.replaceFirst('sex=f', 'sex=x'),
        value.replaceFirst('lon=110.4', 'lon=400.0'),
        'v1 date=1990-02-03',
        'v9 ${value.substring(3)}',
      ]) {
        expect(BaziRecord.parse(broken), isNull, reason: broken);
      }
      expect(BaziRecord.parse(null), isNull);
    });

    test('a chart\'s entry keeps its inputs in its file, out of its text', () {
      final entry = Entry(
        id: '',
        date: day,
        minuteOfDay: 9 * 60,
        utcOffset: offset,
        categoryId: 'ritual',
        title: 'Ana',
        content: 'Strong water.',
        bazi: 'v1 date=1990-02-03 time=15:30',
      );
      final file = EntryFile.encode(entry, categoryName: 'Occasion');
      expect(file, contains('\nbazi: v1 date=1990-02-03 time=15:30\n'));
      final back = EntryFile.decode(file)!;
      expect(back.bazi, entry.bazi);
      expect(back.content, 'Strong water.');
      expect(back.sameAs(entry.at(entry.secondOfDay)), isTrue);
    });

    testWidgets('writes the chart as its inputs, opens the entry to be named '
        'with a toast on a strip of panel, and draws it as a card', (
      tester,
    ) async {
      await pump(tester);
      final journal = tester
          .widget<JournalScope>(find.byType(JournalScope))
          .notifier!;
      final category = journal.categories.first;
      await card(tester, 'bazi-export');
      await tester.tap(key('bazi-export-${category.id}'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryScreen), findsOneWidget);
      // Nothing is in the journal until the tick.
      expect(journal.allEntries().where((e) => e.bazi != null), isEmpty);
      expect(key('entry-bazi-card'), findsOneWidget);
      // The title is chosen, to be typed over.
      final title = tester.widget<SmTextField>(key('entry-title'));
      expect(title.controller.text, 'Bazi chart · 12 October 2026 · 10:00');
      expect(title.controller.selection.end, title.controller.text.length);
      await tester.enterText(key('entry-title'), 'Ana');
      await tester.enterText(key('entry-content'), 'Strong water.');
      await tester.tap(key('entry-save'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Written to the journal.'), findsOneWidget);
      expect(key('entry-toast-strip'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 4));
      final named = journal.allEntries().where((e) => e.bazi != null).single;
      expect(named.title, 'Ana');
      expect(named.content, 'Strong water.');
      expect(BaziRecord.parse(named.bazi)!.minute, 10 * 60);
      // Read: the name first, the moment under it, then the card, with
      // the pillars drawn from the inputs.
      expect(
        tester.getRect(key('entry-title')).top,
        lessThan(tester.getRect(key('entry-when')).top),
      );
      expect(key('entry-bazi-card'), findsOneWidget);
      expect(
        find.descendant(
          of: key('entry-bazi-card'),
          matching: key('pillar-day'),
        ),
        findsOneWidget,
      );
      expect(key('entry-toast-strip'), findsNothing);
    });

    testWidgets('a chart opened from its entry is corrected and written back: '
        'the inputs change, the title and the writing stay', (tester) async {
      await pump(tester);
      final journal = tester
          .widget<JournalScope>(find.byType(JournalScope))
          .notifier!;
      final record = BaziRecord(
        date: CivilDate(1990, 2, 3),
        minute: 15 * 60 + 30,
        offset: offset,
        zone: null,
        longitude: null,
        male: null,
        config: const BaziConfig(),
        hidden: 'ziping.v1',
        relations: 'ziping.v1',
      );
      final entry = journal.save(
        Entry(
          id: '',
          date: CivilDate(2026, 10, 15),
          minuteOfDay: 9 * 60,
          utcOffset: offset,
          categoryId: journal.categories.first.id,
          title: 'Ana',
          content: 'Strong water.',
          bazi: record.value,
        ),
      );
      await pump(
        tester,
        home: EntryScreen(
          date: entry.date,
          utcOffset: entry.utcOffset,
          entry: entry,
        ),
      );
      final again = tester
          .widget<JournalScope>(find.byType(JournalScope))
          .notifier!;
      final mine = again.save(entry.copyWith());
      expect(mine.bazi, record.value);
      await pump(
        tester,
        home: EntryScreen(
          date: mine.date,
          utcOffset: mine.utcOffset,
          entry: mine,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      await tester.tap(key('entry-bazi-card'));
      await tester.pumpAndSettle();
      expect(find.byType(BaziScreen), findsOneWidget);
      expect(find.text('Bazi entry for Ana loaded'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: key('bazi-entry-capsule'),
                matching: find.byType(Text),
              ),
            )
            .data,
        'Ana',
      );
      // Under Options, discard and save in place of read and write.
      await options(tester);
      expect(key('bazi-read'), findsNothing);
      expect(key('bazi-discard'), findsOneWidget);
      // Its tables, read from the app's files.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('3 February 1990 · 15:30'), findsWidgets);
      // A sex given, and written back over the entry.
      await tap(tester, 'bazi-field-sex');
      await tap(tester, 'bazi-sex-false');
      await card(tester, 'bazi-export');
      expect(key('bazi-write-ask'), findsOneWidget);
      await tester.tap(key('bazi-write-edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Back on the entry, which says so.
      expect(find.byType(BaziScreen), findsNothing);
      expect(find.text('The entry was changed.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 4));
      final store = tester
          .widget<JournalScope>(find.byType(JournalScope))
          .notifier!;
      final changed = store.allEntries().where((e) => e.bazi != null).single;
      expect(changed.title, 'Ana');
      expect(changed.content, 'Strong water.');
      expect(BaziRecord.parse(changed.bazi)!.male, isFalse);
    });

    testWidgets('reads a chart back from the journal, and only a whole one; '
        'writing then asks about that entry', (tester) async {
      await pump(tester);
      final journal = tester
          .widget<JournalScope>(find.byType(JournalScope))
          .notifier!;
      await card(tester, 'bazi-read');
      expect(key('bazi-read-none'), findsOneWidget);

      Entry put(String title, String bazi) => journal.save(
        Entry(
          id: '',
          date: CivilDate(2026, 10, 15),
          minuteOfDay: 9 * 60,
          utcOffset: offset,
          categoryId: journal.categories.first.id,
          title: title,
          content: '',
          bazi: bazi,
        ),
      );
      final whole = put(
        'Ana',
        BaziRecord(
          date: CivilDate(1990, 2, 3),
          minute: 15 * 60 + 30,
          offset: offset,
          zone: null,
          longitude: null,
          male: true,
          config: const BaziConfig(),
          hidden: 'ziping.v1',
          relations: 'ziping.v1',
        ).value,
      );
      final broken = put('Torn', 'v1 date=1990-02-03');
      // Closed by back, and opened again: the list now.
      await back(tester);
      expect(key('bazi-read-none'), findsNothing);
      await card(tester, 'bazi-read');
      expect(key('bazi-read-${whole.id}'), findsOneWidget);
      expect(key('bazi-read-${broken.id}'), findsOneWidget);
      await tester.tap(key('bazi-read-${broken.id}'));
      await tester.pumpAndSettle();
      expect(key('bazi-read-list'), findsOneWidget);
      await tester.tap(key('bazi-read-${whole.id}'));
      await tester.pumpAndSettle();
      expect(key('bazi-read-list'), findsNothing);
      expect(find.textContaining('3 February 1990 · 15:30'), findsWidgets);
      expect(find.text('Bazi entry for Ana loaded'), findsOneWidget);
      // Editing that entry: its name in the top bar, and discard and save
      // in place of read and write under Options.
      expect(key('bazi-entry-capsule'), findsOneWidget);
      expect(key('bazi-read'), findsNothing);
      expect(key('bazi-discard'), findsOneWidget);
      expect(cardGlyph(tester, 'bazi-export'), Glyph.save);
      await card(tester, 'bazi-export');
      expect(
        find.text('Save these changes to "Ana", or as a new entry?'),
        findsOneWidget,
      );
      expect(find.text('Save as new entry'), findsOneWidget);
      // Back, like Cancel, leaves the question and keeps the editing.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(key('bazi-write-ask'), findsNothing);
      expect(find.byType(BaziScreen), findsOneWidget);
      expect(key('bazi-entry-capsule'), findsOneWidget);
      // Discard asks first; Cancel keeps the editing.
      await card(tester, 'bazi-discard');
      expect(find.text('Discard every change made to "Ana"?'), findsOneWidget);
      await tester.tap(key('bazi-cancel'));
      await tester.pumpAndSettle();
      expect(key('bazi-discard-ask'), findsNothing);
      expect(key('bazi-entry-capsule'), findsOneWidget);
      // Discarded: the chart as the entry has it, and editing over.
      await card(tester, 'bazi-discard');
      await tester.tap(key('bazi-discard-yes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Changes discarded'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(key('bazi-entry-capsule'), findsNothing);
      expect(key('bazi-read'), findsOneWidget);
      expect(find.textContaining('3 February 1990 · 15:30'), findsWidgets);
      // Loaded again, then asked about when writing.
      await card(tester, 'bazi-read');
      await tester.tap(key('bazi-read-${whole.id}'));
      await tester.pumpAndSettle();
      await card(tester, 'bazi-export');
      expect(find.textContaining('"Ana"'), findsOneWidget);
      // Saved here: the entry opens, and back on the chart it is no
      // longer being edited.
      await tester.tap(key('bazi-write-edit'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byType(EntryScreen), findsOneWidget);
      // Left by going back, as any page is.
      await back(tester);
      expect(find.byType(EntryScreen), findsNothing);
      expect(key('bazi-entry-capsule'), findsNothing);
      expect(key('bazi-read'), findsOneWidget);
      // The same chart, though, is still the journal's: writing asks.
      await card(tester, 'bazi-export');
      expect(key('bazi-write-ask'), findsOneWidget);
      // That entry deleted meanwhile: writing goes straight to the
      // categories, with nothing to ask about.
      journal.delete(whole);
      await back(tester);
      await card(tester, 'bazi-export');
      expect(key('bazi-write-ask'), findsNothing);
      expect(key('bazi-export-${journal.categories.first.id}'), findsOneWidget);
    });

    testWidgets('speaks Indonesian, and reads the characters in pinyin, '
        'as the English does', (tester) async {
      await pump(tester, language: AppLanguage.id);
      expect(find.text('Bagan Bazi'), findsOneWidget);
      // Bing, the year's stem: in pinyin, not the Hokkien pian.
      expect(
        find.descendant(of: key('pillar-year'), matching: find.text('bǐng')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key('pillar-year'), matching: find.text('pian')),
        findsNothing,
      );
      expect(
        find.descendant(of: key('pillar-year'), matching: find.text('Kuda')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(key('bazi-term-before')).data,
        contains('寒露 Embun Dingin'),
      );
    });
  });
}
