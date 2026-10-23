import 'package:candra/app_shell.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/main.dart';
import 'package:candra/sky_place.dart';
import 'package:candra/strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

void main() {
  Future<void> pump(WidgetTester tester, Entry entry) async {
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: EntryScreen(
          date: entry.date,
          utcOffset: entry.utcOffset,
          entry: entry,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 17:40 at Yogyakarta on 16 October 2026: the sun just set (17:42 by
  // the ephemeris), in the evening golden hour, the moon a crescent.
  final entry = Entry(
    id: '20261016-174000',
    date: CivilDate(2026, 10, 16),
    minuteOfDay: 17 * 60 + 40,
    utcOffset: const Duration(hours: 7),
    categoryId: 'ritual',
    title: 'Dusk',
    content: 'The river.',
  );

  testWidgets('an entry reads its moment\'s sky: the light and the sun at '
      'its place, and the moon', (tester) async {
    SkyPlace.current.value = (latitude: -7.8, longitude: 110.4);
    addTearDown(() => SkyPlace.current.value = null);
    await pump(tester, entry);
    final stamp = tester
        .widget<Text>(find.byKey(const ValueKey('entry-sky-stamp')))
        .data!;
    expect(stamp, startsWith('Golden hour · sun '));
    expect(stamp, contains('° W'));
    expect(stamp, endsWith('% lit'));
  });

  testWidgets('with no place, the moon alone', (tester) async {
    await pump(tester, entry);
    final stamp = tester
        .widget<Text>(find.byKey(const ValueKey('entry-sky-stamp')))
        .data!;
    expect(stamp, startsWith('moon '));
  });
}
