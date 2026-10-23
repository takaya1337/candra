import 'package:candra/app_shell.dart';
import 'package:candra/journal/entry.dart';
import 'package:candra/journal/entry_screen.dart';
import 'package:candra/journal/journal_store.dart';
import 'package:candra/main.dart';
import 'package:candra/strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// A double tap on a word selects it, in every field that can be read or
/// written, on Android and on iOS. (On Android a tap puts a handle under
/// the caret; its reach once lay over the line touched and took the
/// second tap.)
void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final editing in [false, true]) {
      testWidgets('a double tap selects the word: ${platform.name}, '
          '${editing ? 'writing' : 'reading'}', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        tester.view.physicalSize = const Size(1440, 3040);
        tester.view.devicePixelRatio = 3.5;
        addTearDown(tester.view.reset);
        final store = JournalStore();
        final day = CivilDate(2026, 10, 15);
        final entry = store.save(
          Entry(
            id: '',
            date: day,
            minuteOfDay: 600,
            utcOffset: const Duration(hours: 7),
            categoryId: store.categories.first.id,
            title: 'Garden notes',
            content: 'alpha bravo charlie delta',
          ),
        );
        await tester.pumpWidget(
          CalendarJournalApp(
            controller: SystemController(),
            language: LanguageController(saved: AppLanguage.en),
            journal: store,
            home: EntryScreen(
              date: day,
              utcOffset: const Duration(hours: 7),
              entry: entry,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (editing) {
          await tester.tap(find.byKey(const ValueKey('entry-edit')));
          await tester.pumpAndSettle();
        }
        final field = find.byKey(const ValueKey('entry-content'));
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final state = tester.state<EditableTextState>(editable);
        final box = state.renderEditable;
        final rect = box
            .getBoxesForSelection(
              const TextSelection(baseOffset: 6, extentOffset: 11),
            )
            .first
            .toRect();
        final at = box.localToGlobal(rect.center);
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(at);
        await tester.pumpAndSettle();
        final sel = state.textEditingValue.selection;
        debugDefaultTargetPlatformOverride = null;
        expect(sel, const TextSelection(baseOffset: 6, extentOffset: 11));
      });
    }
  }
}
