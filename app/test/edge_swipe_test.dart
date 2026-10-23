import 'package:candra/app_shell.dart';
import 'package:candra/main.dart';
import 'package:candra/house.dart';
import 'package:candra/menu/colours_screen.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// On an iPhone a screen opened inside a room is drawn off from the left
/// edge to go back, and from nowhere else; on Android the phone itself
/// does that, and the app does nothing.
void main() {
  Future<void> openPage(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = const Size(1440, 3040);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: MonthScreen(
          today: CivilDate(2026, 10, 15),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // On an iPhone the bar is the phone's own: go to the menu as its
    // button does, and open a page in it.
    House.maybeOf(tester.element(find.byType(MonthScreen)))!.go(Room.menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-colours')));
    await tester.pumpAndSettle();
    expect(find.byType(ColoursScreen), findsOneWidget);
  }

  Future<void> swipe(WidgetTester tester, double from, double by) async {
    final gesture = await tester.startGesture(Offset(from, 400));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset(from + by * i / 10, 400));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  const width = 1440 / 3.5;

  testWidgets('from the left edge, rightwards: back', (tester) async {
    await openPage(tester, TargetPlatform.iOS);
    await swipe(tester, 4, 200);
    expect(find.byType(ColoursScreen), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('from the right edge, leftwards: nothing', (tester) async {
    await openPage(tester, TargetPlatform.iOS);
    await swipe(tester, width - 4, -200);
    expect(find.byType(ColoursScreen), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a short, slow draw slides home again', (tester) async {
    await openPage(tester, TargetPlatform.iOS);
    final gesture = await tester.startGesture(const Offset(4, 400));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset(4 + 4.0 * i, 400));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(ColoursScreen), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('colours-top-bar'))).dx,
      lessThan(30),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('drawing does not make the screen anew: the same screen '
      'follows the finger and comes home', (tester) async {
    await openPage(tester, TargetPlatform.iOS);
    final before = tester.state(find.byType(ColoursScreen));
    final gesture = await tester.startGesture(const Offset(4, 400));
    await gesture.moveTo(const Offset(40, 400));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(const Offset(60, 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.state(find.byType(ColoursScreen)), same(before));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('colours-top-bar'))).dx,
      greaterThan(30),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ColoursScreen)), same(before));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a draw that starts away from the edges does nothing', (
    tester,
  ) async {
    await openPage(tester, TargetPlatform.iOS);
    await swipe(tester, 120, 200);
    expect(find.byType(ColoursScreen), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on Android the app leaves it to the phone', (tester) async {
    await openPage(tester, TargetPlatform.android);
    await swipe(tester, 4, 200);
    expect(find.byType(ColoursScreen), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
